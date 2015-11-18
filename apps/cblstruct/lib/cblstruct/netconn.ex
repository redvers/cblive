defmodule Cblstruct.Netconn do
  defstruct guid: nil, segment_id: nil, localv4: nil, localport: nil, remotev4: nil, remoteport: nil, proto: nil, direction: nil, netpath: nil

  def sample do
    %Cblstruct.Netconn{guid: 158456349157000791004023598261, localv4: 16777343, remotev4: 16777343, localport: 20480}
  end

  def pid(struct) do
    << _sensorid :: size(32), process_pid :: size(32), _process_create_time :: size(64) >> = << struct.guid :: size(128) >>
    process_pid
  end

  def sensor_id(struct) do
    << sensorid :: size(32), _process_pid :: size(32), _process_create_time :: size(64) >> = << struct.guid :: size(128) >>
    sensorid
  end

  def process_create_time(struct) do
    << _sensorid :: size(32), _process_pid :: size(32), process_create_time :: size(64) >> = << struct.guid :: size(128) >>
    process_create_time
  end

  def string_localv4(struct) do
    << a :: size(8), b :: size(8), c :: size(8), d :: size(8) >> = << struct.localv4 :: little-size(32) >>
    "#{a}.#{b}.#{c}.#{d}"
  end

  def string_remotev4(struct) do
    << a :: size(8), b :: size(8), c :: size(8), d :: size(8) >> = << struct.remotev4 :: little-size(32) >>
    "#{a}.#{b}.#{c}.#{d}"
  end

  def to_printable_guid(struct) do
    :io_lib.format('~32.16.0b', [struct.guid])
    |> List.flatten
    |> List.insert_at(8, '-')
    |> List.insert_at(13, '-')
    |> List.insert_at(18, '-')
    |> List.insert_at(23, '-')
    |> to_string
  end

  def from_printable_guid(_struct) do
    # returns that gorgous bitstring
  end

  def localport(struct) do
    << a :: little-size(16) >> = << struct.localport :: big-size(16) >>
    a
  end

  def remoteport(struct) do
    << a :: little-size(16) >> = << struct.remoteport :: big-size(16) >>
    a
  end
end
