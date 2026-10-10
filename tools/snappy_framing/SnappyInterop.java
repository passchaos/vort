import java.io.*;
import java.nio.file.*;
import org.xerial.snappy.Snappy;
import org.xerial.snappy.SnappyInputStream;
import org.xerial.snappy.SnappyOutputStream;

public final class SnappyInterop {
    private static byte[] read(String path) throws IOException {
        return Files.readAllBytes(Path.of(path));
    }

    private static void write(String path, byte[] data) throws IOException {
        Files.write(Path.of(path), data);
    }

    private static void xerialEncode(String input, String output) throws IOException {
        try (OutputStream out = new SnappyOutputStream(new FileOutputStream(output))) {
            out.write(read(input));
        }
    }

    private static void xerialDecode(String input, String output) throws IOException {
        try (InputStream in = new SnappyInputStream(new FileInputStream(input))) {
            write(output, in.readAllBytes());
        }
    }

    private static void hadoopEncode(String input, String output) throws IOException {
        byte[] data = read(input);
        try (DataOutputStream out = new DataOutputStream(new FileOutputStream(output))) {
            for (int blockStart = 0; blockStart < data.length; blockStart += 256 * 1024) {
                int blockLen = Math.min(256 * 1024, data.length - blockStart);
                out.writeInt(blockLen);
                for (int chunkStart = 0; chunkStart < blockLen; chunkStart += 64 * 1024) {
                    int chunkLen = Math.min(64 * 1024, blockLen - chunkStart);
                    byte[] plain = new byte[chunkLen];
                    System.arraycopy(data, blockStart + chunkStart, plain, 0, chunkLen);
                    byte[] compressed = Snappy.compress(plain);
                    out.writeInt(compressed.length);
                    out.write(compressed);
                }
            }
        }
    }

    private static void hadoopDecode(String input, String output) throws IOException {
        try (DataInputStream in = new DataInputStream(new FileInputStream(input));
             ByteArrayOutputStream decoded = new ByteArrayOutputStream()) {
            while (in.available() != 0) {
                int expected = in.readInt();
                if (expected <= 0) throw new IOException("invalid Hadoop block size");
                int written = 0;
                while (written < expected) {
                    int compressedLen = in.readInt();
                    if (compressedLen <= 0) throw new IOException("invalid Hadoop chunk size");
                    byte[] compressed = in.readNBytes(compressedLen);
                    if (compressed.length != compressedLen) throw new EOFException();
                    byte[] plain = Snappy.uncompress(compressed);
                    decoded.write(plain);
                    written += plain.length;
                }
                if (written != expected) throw new IOException("Hadoop block size mismatch");
            }
            write(output, decoded.toByteArray());
        }
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 3) throw new IllegalArgumentException("mode input output");
        switch (args[0]) {
            case "xerial-encode": xerialEncode(args[1], args[2]); break;
            case "xerial-decode": xerialDecode(args[1], args[2]); break;
            case "hadoop-encode": hadoopEncode(args[1], args[2]); break;
            case "hadoop-decode": hadoopDecode(args[1], args[2]); break;
            default: throw new IllegalArgumentException("unknown mode");
        }
    }
}
