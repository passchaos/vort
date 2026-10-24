#!/usr/bin/env python3
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(*args: object, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(arg) for arg in args],
        cwd=cwd,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--writer", required=True, type=Path)
    parser.add_argument("--ar", dest="ar_tool", type=Path)
    parser.add_argument("--llvm-ar", dest="llvm_ar_tool", type=Path)
    parser.add_argument("--llvm-nm", dest="llvm_nm_tool", type=Path)
    parser.add_argument("--clang", dest="clang_tool", type=Path)
    args = parser.parse_args()
    ar_tool = args.ar_tool
    if ar_tool is None:
        found = shutil.which("ar")
        ar_tool = Path(found) if found else None
    llvm_ar_tool = args.llvm_ar_tool
    if llvm_ar_tool is None:
        for name in ("llvm-ar", "llvm-ar-20", "llvm-ar-19", "llvm-ar-18", "llvm-ar-17", "llvm-ar-14"):
            found = shutil.which(name)
            if found is not None:
                llvm_ar_tool = Path(found)
                break
    llvm_nm_tool = args.llvm_nm_tool
    if llvm_nm_tool is None:
        for name in ("llvm-nm", "llvm-nm-20", "llvm-nm-19", "llvm-nm-18", "llvm-nm-17", "llvm-nm-14"):
            found = shutil.which(name)
            if found is not None:
                llvm_nm_tool = Path(found)
                break
    cc_tool = shutil.which("cc")
    nm_tool = shutil.which("nm")
    clang_tool = args.clang_tool
    if clang_tool is None:
        found = shutil.which("clang") or shutil.which("clang-14")
        clang_tool = Path(found) if found else None

    expected = {
        "short.txt": b"short ar payload\n",
        "very-long-member-name-for-vort.txt": b"long ar payload\n",
        "odd.bin": bytes(range(5)),
    }
    self_cases = 0
    external_read = 0
    external_write = 0
    symbol_read = 0
    thin_self = 0
    thin_external_read = 0
    thin_external_write = 0
    thin_symbol_read = 0
    thin_symbol_write = 0
    thin_symbol_link = 0
    bsd_symbol_read = 0
    bsd_symbol_write = 0
    bsd_symbol_extract = 0
    bsd_symbol_link = 0
    malformed = 0

    with tempfile.TemporaryDirectory(prefix="vort-ar-diff-") as temp_text:
        temp = Path(temp_text)
        vort_archive = temp / "vort.a"
        run(args.writer, vort_archive)
        listing = run(args.cli, "list-ar-file", vort_archive).stdout
        if "ar_entries=3" not in listing:
            raise AssertionError(f"Vort ar writer count mismatch: {listing}")
        for index, (name, data) in enumerate(expected.items()):
            if f"name={name}" not in listing:
                raise AssertionError(f"Vort ar writer omitted {name}: {listing}")
            output = temp / f"self-{index}.out"
            run(args.cli, "extract-ar-file", vort_archive, name, output, len(data))
            if output.read_bytes() != data:
                raise AssertionError(f"Vort ar self extraction mismatch: {name}")
            self_cases += 1

        if ar_tool is not None:
            names = tuple(line for line in run(ar_tool, "t", vort_archive).stdout.splitlines() if line)
            if names != tuple(expected):
                raise AssertionError(f"GNU ar rejected Vort member names: {names}")
            extracted = temp / "gnu-extracted"
            extracted.mkdir()
            run(ar_tool, "x", vort_archive, cwd=extracted)
            for name, data in expected.items():
                if (extracted / name).read_bytes() != data:
                    raise AssertionError(f"GNU ar rejected Vort data: {name}")
                external_read += 1

            source = temp / "gnu-source"
            source.mkdir()
            for name, data in expected.items():
                (source / name).write_bytes(data)
            gnu_archive = temp / "gnu.a"
            run(ar_tool, "rcs", gnu_archive, *expected.keys(), cwd=source)
            gnu_listing = run(args.cli, "list-ar-file", gnu_archive).stdout
            if "ar_entries=3" not in gnu_listing:
                raise AssertionError(f"Vort rejected GNU ar members: {gnu_listing}")
            for index, (name, data) in enumerate(expected.items()):
                output = temp / f"gnu-{index}.out"
                run(args.cli, "extract-ar-file", gnu_archive, name, output, len(data))
                if output.read_bytes() != data:
                    raise AssertionError(f"Vort rejected GNU ar data: {name}")
                external_write += 1

            thin_expected = {
                "short.txt": b"short thin payload\n",
                "very-long-member-name-for-thin-ar.txt": b"long thin payload\n",
            }
            thin_source = temp / "thin-source"
            thin_source.mkdir()
            for name, data in thin_expected.items():
                (thin_source / name).write_bytes(data)
            thin_archive = thin_source / "gnu-thin.a"
            run(ar_tool, "rcT", thin_archive.name, *thin_expected.keys(), cwd=thin_source)
            thin_listing = run(args.cli, "list-ar-file", thin_archive).stdout
            if "thin=true" not in thin_listing or "external=true" not in thin_listing:
                raise AssertionError(f"Vort lost GNU thin metadata: {thin_listing}")
            for index, (name, data) in enumerate(thin_expected.items()):
                output = temp / f"gnu-thin-{index}.out"
                run(
                    args.cli,
                    "extract-ar-file",
                    thin_archive,
                    name,
                    output,
                    len(data),
                    thin_source / name,
                )
                if output.read_bytes() != data:
                    raise AssertionError(f"Vort rejected GNU thin member: {name}")
                thin_external_write += 1

            if cc_tool is not None:
                object_source = thin_source / "object.c"
                object_path = thin_source / "very-long-object-member-name.o"
                object_source.write_text(
                    "int vort_thin_symbol(void) { return 42; }\n"
                    "int vort_thin_data = 7;\n"
                    "int vort_thin_alias(void) { return vort_thin_symbol(); }\n"
                )
                run(cc_tool, "-c", object_source.name, "-o", object_path.name, cwd=thin_source)
                object_archive = thin_source / "gnu-thin-object.a"
                run(
                    ar_tool,
                    "rcsT",
                    object_archive.name,
                    object_path.name,
                    cwd=thin_source,
                )
                object_listing = run(args.cli, "list-ar-file", object_archive).stdout
                if (
                    "ar_entries=1" not in object_listing
                    or "ar_symbols=3" not in object_listing
                    or "thin=true" not in object_listing
                    or "name=vort_thin_symbol" not in object_listing
                    or "name=vort_thin_data" not in object_listing
                    or "name=vort_thin_alias" not in object_listing
                    or f"member={object_path.name}" not in object_listing
                ):
                    raise AssertionError(
                        f"Vort rejected GNU thin symbol table: {object_listing}"
                    )
                thin_symbol_read += 1
                object_output = temp / "gnu-thin-object.out"
                run(
                    args.cli,
                    "extract-ar-file",
                    object_archive,
                    object_path.name,
                    object_output,
                    object_path.stat().st_size,
                    object_path,
                )
                if object_output.read_bytes() != object_path.read_bytes():
                    raise AssertionError("Vort rejected a GNU thin object member")
                thin_external_write += 1

                regular_object_archive = thin_source / "gnu-object.a"
                run(
                    ar_tool,
                    "rcs",
                    regular_object_archive.name,
                    object_path.name,
                    cwd=thin_source,
                )
                regular_object_listing = run(
                    args.cli,
                    "list-ar-file",
                    regular_object_archive,
                ).stdout
                if (
                    "ar_entries=1" not in regular_object_listing
                    or "ar_symbols=3" not in regular_object_listing
                    or "thin=false" not in regular_object_listing
                    or "name=vort_thin_symbol" not in regular_object_listing
                    or "name=vort_thin_data" not in regular_object_listing
                    or "name=vort_thin_alias" not in regular_object_listing
                    or f"member={object_path.name}" not in regular_object_listing
                ):
                    raise AssertionError(
                        "Vort rejected GNU regular ar symbol table: "
                        f"{regular_object_listing}"
                    )
                symbol_read += 1

            (thin_source / "short.txt").write_bytes(b"x")
            failed = run(
                args.cli,
                "extract-ar-file",
                thin_archive,
                "short.txt",
                temp / "thin-shortened.out",
                "1024",
                thin_source / "short.txt",
                check=False,
            )
            if failed.returncode == 0 or "SizeMismatch" not in failed.stderr:
                raise AssertionError("Vort accepted a shortened thin member source")
            malformed += 1

            unsafe_source = temp / "outside.txt"
            unsafe_source.write_bytes(b"outside thin payload\n")
            unsafe_dir = temp / "unsafe"
            unsafe_dir.mkdir()
            unsafe_archive = unsafe_dir / "unsafe.a"
            run(ar_tool, "rcT", unsafe_archive.name, "../outside.txt", cwd=unsafe_dir)
            unsafe_listing = run(args.cli, "list-ar-file", unsafe_archive).stdout
            if "safe_path=false" not in unsafe_listing:
                raise AssertionError(f"Vort lost unsafe thin path metadata: {unsafe_listing}")
            failed = run(
                args.cli,
                "extract-ar-file",
                unsafe_archive,
                "../outside.txt",
                temp / "unsafe-thin.out",
                "1024",
                check=False,
            )
            if failed.returncode == 0 or "ArEntryRequiresResolver" not in failed.stderr:
                raise AssertionError("Vort CLI resolved a thin member without explicit source")
            malformed += 1

            vort_thin = temp / "vort-thin.a"
            run(args.writer, vort_thin, "thin")
            vort_thin_expected = {
                "thin-short.txt": b"thin short payload\n",
                "thin/very-long-member-name-for-vort.txt": b"thin long payload\n",
            }
            vort_thin_listing = run(args.cli, "list-ar-file", vort_thin).stdout
            if "ar_entries=2" not in vort_thin_listing or "thin=true" not in vort_thin_listing:
                raise AssertionError(f"Vort thin writer metadata mismatch: {vort_thin_listing}")
            for index, (name, data) in enumerate(vort_thin_expected.items()):
                output = temp / f"vort-thin-{index}.out"
                run(
                    args.cli,
                    "extract-ar-file",
                    vort_thin,
                    name,
                    output,
                    len(data),
                    temp / name,
                )
                if output.read_bytes() != data:
                    raise AssertionError(f"Vort thin self extraction mismatch: {name}")
                thin_self += 1
                actual = run(ar_tool, "p", vort_thin, name).stdout.encode()
                if actual != data:
                    raise AssertionError(f"GNU ar rejected Vort thin member: {name}")
                thin_external_read += 1

            if cc_tool is not None:
                first_source = temp / "thin-first.c"
                first_object = temp / "thin-first.o"
                second_source = temp / "thin-second.c"
                second_object = temp / "thin" / "very-long-symbol-member.o"
                first_source.write_text(
                    "int zeta(void) { return 7; }\n"
                    "int alpha(void) { return 11; }\n"
                    "int shared_a = 3;\n"
                    "static int hidden(void) { return 1; }\n"
                )
                second_source.write_text(
                    "int beta(void) { return 22; }\n"
                    "int shared_b = 5;\n"
                    "extern int alpha(void);\n"
                    "int calls_alpha(void) { return alpha(); }\n"
                )
                run(cc_tool, "-c", first_source, "-o", first_object)
                run(cc_tool, "-c", second_source, "-o", second_object)
                main_source = temp / "thin-main.c"
                main_object = temp / "thin-main.o"
                main_source.write_text(
                    "extern int beta(void);\n"
                    "extern int calls_alpha(void);\n"
                    "extern int shared_a;\n"
                    "extern int shared_b;\n"
                    "int main(void) {\n"
                    "  return beta() == 22 && calls_alpha() == 11 && "
                    "shared_a == 3 && shared_b == 5 ? 0 : 1;\n"
                    "}\n"
                )
                run(cc_tool, "-c", main_source, "-o", main_object)

                for symbol_mode in ("thin-symbols", "thin-symbols64"):
                    symbol_archive = temp / f"vort-{symbol_mode}.a"
                    run(args.writer, symbol_archive, symbol_mode)
                    symbol_listing = run(args.cli, "list-ar-file", symbol_archive).stdout
                    required = (
                        "ar_entries=2",
                        "ar_symbols=5",
                        "member=thin-first.o name=alpha",
                        "member=thin/very-long-symbol-member.o name=beta",
                        "member=thin/very-long-symbol-member.o name=calls_alpha",
                    )
                    if any(value not in symbol_listing for value in required):
                        raise AssertionError(
                            f"Vort thin symbol metadata mismatch ({symbol_mode}): "
                            f"{symbol_listing}"
                        )
                    symbol_names = tuple(
                        line
                        for line in run(
                            ar_tool,
                            "t",
                            symbol_archive.name,
                            cwd=temp,
                        ).stdout.splitlines()
                        if line
                    )
                    if symbol_names != (
                        "thin-first.o",
                        "thin/very-long-symbol-member.o",
                    ):
                        raise AssertionError(
                            f"GNU ar rejected Vort symbol members ({symbol_mode}): "
                            f"{symbol_names}"
                        )
                    if nm_tool is not None:
                        armap = run(
                            nm_tool,
                            "--print-armap",
                            symbol_archive.name,
                            cwd=temp,
                        ).stdout
                        for expected_line in (
                            "alpha in thin-first.o",
                            "shared_a in thin-first.o",
                            "beta in thin/very-long-symbol-member.o",
                            "shared_b in thin/very-long-symbol-member.o",
                            "calls_alpha in thin/very-long-symbol-member.o",
                        ):
                            if expected_line not in armap:
                                raise AssertionError(
                                    f"GNU nm rejected Vort armap ({symbol_mode}): {armap}"
                                )
                        thin_symbol_write += 1
                    executable = temp / f"vort-{symbol_mode}-linked"
                    run(cc_tool, main_object, symbol_archive, "-o", executable, cwd=temp)
                    run(executable, cwd=temp)
                    thin_symbol_link += 1

                bsd_first = temp / "bsd-first.o"
                bsd_dir = temp / "bsd"
                bsd_dir.mkdir()
                bsd_second = bsd_dir / "very-long-symbol-member.o"
                shutil.copyfile(first_object, bsd_first)
                shutil.copyfile(second_object, bsd_second)
                bsd_member_names = (
                    bsd_first.name,
                    f"{bsd_dir.name}/{bsd_second.name}",
                )
                llvm_member_names = (bsd_first.name, bsd_second.name)

                if llvm_ar_tool is not None:
                    for llvm_format in ("bsd", "darwin"):
                        llvm_archive = temp / f"llvm-{llvm_format}.a"
                        run(
                            llvm_ar_tool,
                            f"--format={llvm_format}",
                            "rcs",
                            llvm_archive.name,
                            *bsd_member_names,
                            cwd=temp,
                        )
                        llvm_listing = run(
                            args.cli,
                            "list-ar-file",
                            llvm_archive,
                        ).stdout
                        required = (
                            "ar_entries=2",
                            "ar_symbols=6",
                            "ar_symbol_format=bsd32",
                            "member=bsd-first.o name=zeta",
                            "member=bsd-first.o name=alpha",
                            "member=very-long-symbol-member.o name=beta",
                            "member=very-long-symbol-member.o name=calls_alpha",
                        )
                        if any(value not in llvm_listing for value in required):
                            raise AssertionError(
                                f"Vort rejected LLVM {llvm_format} armap: "
                                f"{llvm_listing}"
                            )
                        for index, (name, expected_path) in enumerate(
                            zip(llvm_member_names, (bsd_first, bsd_second))
                        ):
                            output = temp / f"llvm-{llvm_format}-{index}.out"
                            run(
                                args.cli,
                                "extract-ar-file",
                                llvm_archive,
                                name,
                                output,
                                expected_path.stat().st_size,
                            )
                            if output.read_bytes() != expected_path.read_bytes():
                                raise AssertionError(
                                    f"Vort rejected LLVM {llvm_format} member {name}"
                                )
                        bsd_symbol_read += 1

                bsd_modes = (
                    ("bsd-symbols", "bsd32", False),
                    ("bsd-symbols-sorted", "bsd32_sorted", True),
                    ("bsd-symbols64", "bsd64", False),
                    ("bsd-symbols64-sorted", "bsd64_sorted", True),
                )
                unsorted_names = (
                    "zeta",
                    "alpha",
                    "shared_a",
                    "beta",
                    "shared_b",
                    "calls_alpha",
                )
                sorted_names = tuple(sorted(unsorted_names))
                for bsd_mode, expected_format, sorted_index in bsd_modes:
                    bsd_archive = temp / f"vort-{bsd_mode}.a"
                    run(args.writer, bsd_archive, bsd_mode)
                    bsd_listing = run(args.cli, "list-ar-file", bsd_archive).stdout
                    required = (
                        "ar_entries=2",
                        "ar_symbols=6",
                        f"ar_symbol_format={expected_format}",
                        "member=bsd-first.o name=alpha",
                        "member=bsd/very-long-symbol-member.o name=beta",
                    )
                    if any(value not in bsd_listing for value in required):
                        raise AssertionError(
                            f"Vort BSD symbol metadata mismatch ({bsd_mode}): "
                            f"{bsd_listing}"
                        )
                    listed_symbols = tuple(
                        line.rsplit("name=", 1)[1]
                        for line in bsd_listing.splitlines()
                        if line.startswith("symbol_index=")
                    )
                    expected_symbols = sorted_names if sorted_index else unsorted_names
                    if listed_symbols != expected_symbols:
                        raise AssertionError(
                            f"Vort BSD symbol order mismatch ({bsd_mode}): "
                            f"{listed_symbols}"
                        )

                    if clang_tool is not None:
                        executable = temp / f"vort-{bsd_mode}-linked"
                        linked = run(
                            clang_tool,
                            "-fuse-ld=lld",
                            main_object,
                            bsd_archive,
                            "-o",
                            executable,
                            cwd=temp,
                            check=False,
                        )
                        if linked.returncode != 0:
                            raise AssertionError(
                                f"LLVM linker rejected Vort BSD armap ({bsd_mode}): "
                                f"{linked.stderr}"
                            )
                        run(executable, cwd=temp)
                        bsd_symbol_link += 1

                    if llvm_ar_tool is not None:
                        member_names = tuple(
                            line
                            for line in run(
                                llvm_ar_tool,
                                "t",
                                bsd_archive.name,
                                cwd=temp,
                            ).stdout.splitlines()
                            if line
                        )
                        if member_names != bsd_member_names:
                            raise AssertionError(
                                f"LLVM ar rejected Vort BSD members ({bsd_mode}): "
                                f"{member_names}"
                            )
                        for name, expected_path in zip(
                            bsd_member_names,
                            (bsd_first, bsd_second),
                        ):
                            extracted = subprocess.run(
                                [str(llvm_ar_tool), "p", bsd_archive.name, name],
                                cwd=temp,
                                check=True,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                            ).stdout
                            if extracted != expected_path.read_bytes():
                                raise AssertionError(
                                    f"LLVM ar rejected Vort BSD data ({bsd_mode}, {name})"
                                )
                        bsd_symbol_extract += 1

                    if llvm_nm_tool is not None:
                        armap = run(
                            llvm_nm_tool,
                            "--print-armap",
                            bsd_archive.name,
                            cwd=temp,
                        ).stdout
                        expected_lines = tuple(
                            f"{name} in "
                            + (
                                "bsd-first.o"
                                if name in ("zeta", "alpha", "shared_a")
                                else "bsd/very-long-symbol-member.o"
                            )
                            for name in expected_symbols
                        )
                        positions = tuple(armap.find(line) for line in expected_lines)
                        if any(position < 0 for position in positions) or positions != tuple(
                            sorted(positions)
                        ):
                            raise AssertionError(
                                f"LLVM nm rejected Vort BSD armap ({bsd_mode}): {armap}"
                            )
                        bsd_symbol_write += 1

        corrupt = bytearray(vort_archive.read_bytes())
        corrupt[8 + 58] ^= 1
        corrupt_path = temp / "corrupt.a"
        corrupt_path.write_bytes(corrupt)
        if run(args.cli, "list-ar-file", corrupt_path, check=False).returncode == 0:
            raise AssertionError("Vort accepted a corrupt ar header trailer")
        malformed += 1

    print(
        f"self_cases={self_cases} ar_tool={ar_tool is not None} cc={cc_tool is not None} "
        f"nm={nm_tool is not None} llvm_ar={llvm_ar_tool is not None} "
        f"llvm_nm={llvm_nm_tool is not None} clang={clang_tool is not None} "
        f"external_read={external_read} external_write={external_write} "
        f"symbol_read={symbol_read} "
        f"thin_self={thin_self} thin_external_read={thin_external_read} "
        f"thin_external_write={thin_external_write} "
        f"thin_symbol_read={thin_symbol_read} thin_symbol_write={thin_symbol_write} "
        f"thin_symbol_link={thin_symbol_link} "
        f"bsd_symbol_read={bsd_symbol_read} bsd_symbol_write={bsd_symbol_write} "
        f"bsd_symbol_extract={bsd_symbol_extract} bsd_symbol_link={bsd_symbol_link} "
        f"malformed={malformed}"
    )


if __name__ == "__main__":
    main()
