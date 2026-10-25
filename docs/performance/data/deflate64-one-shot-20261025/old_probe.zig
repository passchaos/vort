const std = @import("std");
const codec = @import("codec");
pub fn main(init: std.process.Init) !void {
 var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
 defer args.deinit();
 _ = args.next();
 var buffer: [4096]u8 = undefined;
 var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
 try stdout.interface.writeAll("[\n");
 var first=true;
 while(args.next()) |path| {
  const input = try std.Io.Dir.cwd().readFileAlloc(init.io,path,init.gpa,.limited(1024*1024));
  defer init.gpa.free(input);
  var heap = std.testing.FailingAllocator.init(init.gpa,.{});
  const encoded = try codec.encodeAlloc(heap.allocator(),input,.{});
  defer heap.allocator().free(encoded);
  const decoded = try codec.decodeAlloc(init.gpa,encoded);
  defer init.gpa.free(decoded);
  if(!std.mem.eql(u8,input,decoded)) return error.Mismatch;
  if(!first) try stdout.interface.writeAll(",\n");
  first=false;
  try std.json.Stringify.value(.{.path=path,.input_bytes=input.len,.input_sha256=std.fmt.bytesToHex(digest(input),.lower),.encoded_bytes=encoded.len,.allocation_requests=heap.alloc_index,.total_requested_bytes=heap.allocated_bytes,.freed_before_output_release=heap.freed_bytes,.wire_sha256=std.fmt.bytesToHex(digest(encoded),.lower),.round_trip=true},.{},&stdout.interface);
 }
 try stdout.interface.writeAll("\n]\n");
 try stdout.interface.flush();
}

fn digest(bytes:[]const u8) [32]u8 { var result:[32]u8=undefined; std.crypto.hash.sha2.Sha256.hash(bytes,&result,.{}); return result; }
