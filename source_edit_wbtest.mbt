///|
test "source edits preserve untouched numeric spelling comments and types" {
  let input = b"# config\nmask=0xFFFFFFFFL; bits=0x100000000L; port=9000; // keep\nname=\"moon\";"
  let output = replace_source_value(input, "port", Integer(8080))
  assert_eq(
    output, b"# config\nmask=0xFFFFFFFFL; bits=0x100000000L; port=8080; // keep\nname=\"moon\";",
  )
  assert_eq(parse_bytes(output).lookup("port"), Integer(8080))
}

///|
test "source string edits preserve trailing trivia and other values" {
  assert_eq(
    replace_source_value(
      b"name=\"old\" /* keep */ ; port=9000",
      "name",
      Text(b"new"),
    ),
    b"name=\"new\" /* keep */ ; port=9000",
  )
}
