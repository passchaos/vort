//! Independent byte oracle: exactly one full-slice write_data followed by finish.
use fdeflate::UltraFastCompressor;
use std::io::{self, BufRead, Write};

fn unhex(value: &str) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    if value.len() % 2 != 0 || !value.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("invalid source hex".into());
    }
    let mut result = Vec::with_capacity(value.len() / 2);
    for pair in value.as_bytes().chunks_exact(2) {
        result.push(u8::from_str_radix(std::str::from_utf8(pair)?, 16)?);
    }
    Ok(result)
}

fn hex(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    let mut result = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        result.push(char::from(DIGITS[(byte >> 4) as usize]));
        result.push(char::from(DIGITS[(byte & 15) as usize]));
    }
    result
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut output = io::BufWriter::new(io::stdout().lock());
    for line in io::stdin().lock().lines() {
        let line = line?;
        let (id, source_hex) = line.split_once('\t').ok_or("expected id-tab-sourcehex")?;
        if id.is_empty() || !id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_') {
            return Err("invalid id".into());
        }
        let source = unhex(source_hex)?;
        let mut compressor = UltraFastCompressor::new(Vec::new())?;
        // This is the sole write_data call, including the empty source case.
        compressor.write_data(&source)?;
        let expected = compressor.finish()?;
        writeln!(output, "{{\"id\":\"{id}\",\"source_hex\":\"{}\",\"expected_hex\":\"{}\",\"write_data_calls\":1}}", hex(&source), hex(&expected))?;
    }
    output.flush()?;
    Ok(())
}
