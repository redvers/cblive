defmodule CblstructTest do
  use ExUnit.Case

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "sampledata is present" do
    assert Cblstruct.Netconn.sample.guid == 158456349157000791004023598261
  end
  test "guid sensor_id" do
    sample = Cblstruct.Netconn.sample
    assert Cblstruct.Netconn.sensor_id(sample) == 2
  end
  test "guid pid" do
    sample = Cblstruct.Netconn.sample
    assert Cblstruct.Netconn.pid(sample) == 1308
  end
  test "guid create_time" do
    sample = Cblstruct.Netconn.sample
    assert Cblstruct.Netconn.process_create_time(sample) == 130867404842183861
  end
  test "guid localv4" do
    sample = Cblstruct.Netconn.sample
    assert Cblstruct.Netconn.localv4(sample) == "127.0.0.1"
  end
  test "guid localport" do
    sample = Cblstruct.Netconn.sample
    assert Cblstruct.Netconn.localport(sample) == 80
  end
  test "guid to_printable_guid" do
    sample = Cblstruct.Netconn.sample
    assert Cblstruct.Netconn.to_printable_guid(sample) == "00000002-0000-051c-01d0-ef361a4bacb5"
  end

end
