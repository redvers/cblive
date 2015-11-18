require Logger

defmodule CB.DateRange do
  @moduledoc """
  Struct for daterange.  Uses native Timex structs.
  """
  defstruct start: (Timex.Date.now |> Timex.Date.subtract({0,8640,0})), end: Timex.Date.now

  @doc """
  Returns a struct for daterange of X days ago to present.
  """

  def days(days) do
    %CB.DateRange{start: (Timex.Date.now |> Timex.Date.subtract({0,(days*86400),0})), end: Timex.Date.now}
  end
end

defmodule CB do
  @moduledoc """
  Provides functions for retrieving and analyzing CB data.  Details for each
  function are provided for each.

  "Types" are implemented either as tagged tuples or structs as appropriate.

  Examples:
    %CB.DateRange{}
    |> CB.process_search("netconn_count:[1 TO *]")
    |> CB.from_server
  """

  @doc """

  Takes no arguments, returns {:sensorlist, [Cblclient.Proccache.Sensor{}, ... ]}

  """
  def searchsensors do
    {:ok, sensors} = Cbclientapi.Sensor.search(creds)
    {:sensorlist, Enum.map(sensors, &atomize_keys/1) |> Enum.map(fn(x) -> struct(Cblclient.Proccache.Sensor, x) end)}
  end

  @doc """
  Takes a CB.DateRange and string.  String is a search string as per Carbon Black documentation.
  """
  def process_search(daterange = %CB.DateRange{}, string) do
    searchstring = "last_update:[" <> Timex.DateFormat.format!(daterange.start, "{YYYY}-{0M}-{0D}T{h24}:{m}:{s}") <> " TO *] AND " <>
                   "start:[* TO "       <> Timex.DateFormat.format!(daterange.end,   "{YYYY}-{0M}-{0D}T{h24}:{m}:{s}") <> "]" <>
                   append_string(string)
    csearch(searchstring)
  end

  def trimtype({_, data}) do
    data
  end

  def extractfield({:procfull, list}, field) do
    Enum.map(list, &(Keyword.get(&1,field)))
  end

  def extractfield({_, list}, field) do
    Enum.map(list, &(Map.get(&1,field)))
  end

  def extractfield(list, field) do
    Enum.map(list, &(Map.get(&1,field)))
  end

  defp csearch(searchstring) do
    url = "https://#{CB.creds.hostname}:#{CB.creds.port}/api/v1/process?q=#{:hackney_url.urlencode(searchstring)}&rows=0"
    Logger.debug url
    {:ok, 200, _headers, bodyref} = :hackney.get(url, [{"X-Auth-Token", CB.creds.api}], '', [ssl_options: [ insecure: true]])
    %{"total_results" => total_results} = :hackney.body(bodyref) |> trim_ok |> JSX.decode |> trim_ok
    {:searchobj, searchstring, total_results}
  end

  defp fsearch(searchstring) do
    url = "https://#{CB.creds.hostname}:#{CB.creds.port}/api/v1/process?q=#{:hackney_url.urlencode(searchstring)}&rows=0&facet=true"
    Logger.debug url
    {:ok, 200, _headers, bodyref} = :hackney.get(url, [{"X-Auth-Token", CB.creds.api}], '', [ssl_options: [ insecure: true]])
    f = :hackney.body(bodyref) |> trim_ok |> JSX.decode
    {:searchobj, searchstring, f}
  end

  @doc """
  Takes a searchobj of some kind and execute the search in parallell on the remote Carbon Black host.
  Returns the appropriate tagged-tuple for the search performed:

    :searchobj returns :procsummaries
  """
  def from_server({:searchobj, searchstring, _}) do
    {:ok, %{"total_results" => total_results}} = Cbclientapi.Process.search(CB.creds, {searchstring, 0})
    pages = div(total_results, 100)
    range = Range.new(0, pages)
    tasklist = Enum.reduce(range, [], fn(pagenum, acc) -> [Task.async(fn -> psearchpage(pagenum, searchstring) end) | acc] end)
    procsummaries = Enum.map(tasklist, fn(task) -> Task.await(task, :infinity) end)
    |> Enum.reduce([], fn({:ok, %{"results" => results}}, acc) -> results ++ acc end)
    |> Enum.map(&map_to_atomized_list/1)
    |> Enum.map(fn(list) -> struct(Cblclient.Proccache.Summary, list) end)
    {:procsummaries, procsummaries}
  end
  def from_server({:procsummaries, list}) do
    urls = Enum.map(list, fn(summary) -> summary.unique_id end)
    |> Enum.map(fn(unique_id) -> Regex.run(~r/^(.*)-[0]*([0-9]+)$/, unique_id) end)
    |> Enum.map(fn([_, guid, segmentdec])-> "https://#{CB.creds.hostname}:#{CB.creds.port}/api/v2/process/#{guid}/#{segmentdec}/event" end)
    tasklist = Enum.reduce(urls, [], fn(url, acc) -> [Task.async(fn -> v2event(url) end) | acc] end)
    procfull = Enum.map(tasklist, fn(task) -> Task.await(task, :infinity) end)
    |> Enum.reduce([], fn({:ok, %{"process" => dataz}}, acc) -> [dataz | acc] end)
    |> Enum.map(&map_to_atomized_list/1)
    |> Enum.map(&normalize_filemod/1)
    |> Enum.map(&normalize_netconn/1)
    {:procfull, procfull}
  end

  def normalize_netconn(fullproc) do
    netconn = Enum.map(fullproc[:netconn_complete], &normalize_netconn_item/1)
    Keyword.put(fullproc, :netconn_complete, netconn)
  end

  def normalize_netconn_item(%{"direction" => direction,
                               "domain" => domain,
                               "local_ip" => local_ip,
                               "local_port" => local_port,
                               "proto" => proto,
                               "remote_ip" => remote_ip,
                               "remote_port" => remote_port,
                               "timestamp" => timestamp}) do
    %Cblclient.Proccache.Netconn{unique_id: nil,
                                 direction: evdirectionnc(direction),
                                 domain: domain,
                                 local_ip: local_ip,
                                 local_port: local_port,
                                 proto: proto,
                                 remote_ip: remote_ip,
                                 remote_port: remote_port,
                                 timestamp: timestamp
                                 }
  end

#  %{"direction" => "true", "domain" => "login.live.com",
#    "local_ip" => -1062731769, "local_port" => 61414, "proto" => 6,
#    "remote_ip" => -2080555678, "remote_port" => 443,
#    "timestamp" => "2015-11-13T21:21:49.969Z"},





def normalize_filemod(fullproc) do
  case fullproc[:filemod_complete] do
    nil -> fullproc
    data ->
           filemod = Enum.map(data, &normalize_filemod_line/1)
           Keyword.put(fullproc, :filemod_complete, filemod)
  end
end

def normalize_filemod_line(filemodline) do
  #  2|2015-11-16 20:04:50.934|c:\users\redvers\appdata\local\microsoft\windows\notifications\wpnidm\5d079b44.jpg|||false
  [event, time, path, md5, type, tamper] = String.split(filemodline, "|")
  %Cblclient.Proccache.Filemod{unique_id: nil,
                               operation: evtypefilemod(event),
                               eventtime: time,
                               filepath: path,
                               md5: md5,
                               filetype: evfiletype(type),
                               tamper: evtamper(tamper)}
end

def evdirectionnc("true") do :true end
def evdirectionnc("false") do :false end
  
def evtypefilemod("1") do :created end
def evtypefilemod("2") do :firstwrite end
def evtypefilemod("4") do :deleted end
def evtypefilemod("8") do :lastwrite end

def evfiletype("1") do :pe end
def evfiletype("2") do :elf end
def evfiletype("3") do :universalbin end
def evfiletype("8") do :eicar end
def evfiletype("16") do :officelegacy end
def evfiletype("17") do :officeopenxml end
def evfiletype("48") do :pdf end
def evfiletype("64") do :archivepkzip end
def evfiletype("65") do :archivelzh end
def evfiletype("66") do :archivelzw end
def evfiletype("67") do :archiverar end
def evfiletype("68") do :archivetar end
def evfiletype("69") do :archive7zip end
def evfiletype("") do :nil end
  
def evtamper("true") do :true end
def evtamper("false") do :false end
def evtamper("") do :nil end
  
  defp map_to_atomized_list(summary) do
    Enum.map(summary, fn({k,v}) -> {String.to_atom(k), v} end)
  end



  def filter({:procsummaries, list}, function) do
    {:procsummaries, Enum.filter(list, fn(processsummary) -> function.(processsummary) end)}
  end
  def filter({:sensorlist, array}, function) do
    {:sensorlist, Enum.filter(array, function)}
  end

  def reject({:procsummaries, list}, function) do
    {:procsummaries, Enum.reject(list, fn(processsummary) -> function.(processsummary) end)}
  end
  def reject({:sensorlist, list}, function) do
    {:sensorlist, Enum.reject(list, fn(processsummary) -> function.(processsummary) end)}
  end

  def regex(field, regexstring) do
    {:ok, regex} = Regex.compile(regexstring)
    fn(summary) -> Regex.match?(regex, Map.get(summary,field)) end
  end

  def iregex(field, regexstring) do
    {:ok, regex} = Regex.compile(regexstring, [:caseless])
    fn(summary) -> Regex.match?(regex, Map.get(summary, field)) end
  end



  defp psearch(creds, searchstring) do
    {:ok, %{"total_results" => total_results}} = Cbclientapi.Process.search(CB.creds, {searchstring, 0})
    pages = div(total_results, 100)
    range = Range.new(0, pages)
    #massawait(tasklist)
  end





  defp psearchpage(pagenum, string) do
    startnum = pagenum * 100
    {:ok, 200, headers, bodyref} = "https://#{CB.creds.hostname}:#{CB.creds.port}/api/v1/process?q=#{:hackney_url.urlencode(string)}&rows=100&start=#{startnum}"
    |> :hackney.get([{"X-Auth-Token", CB.creds.api}], '', [ssl_options: [ insecure: true]])
    Logger.debug("Page #{pagenum} retrieved")
    :hackney.body(bodyref)
    |> trim_ok
    |> JSX.decode
  end

  def v2event(url) do
    case { :hackney.get(url, [{"X-Auth-Token", CB.creds.api}], '', [ssl_options: [ insecure: true]]), url } do
      {{:ok, 200, _, bodyref}, url} ->
        case {:hackney.body(bodyref), url} do
          {{:ok, text}, url} ->
            JSX.decode(text)
          {somethingelse, url} ->
            Logger.debug("#{inspect(somethingelse)} - Retrying #{url}")
            v2event(url)
        end
      {somethingelse, url} ->
        Logger.debug("#{inspect(somethingelse)} - Retrying #{url}")
        v2event(url)
    end
  end





#  iex(30)> CB.searchsensors |> CB.filter(&(&1.os_type == 2))
#  iex(31)> CB.searchsensors |> CB.filter(&(Regex.match?(~r/XP/, &1.os_environment_display_string)))

  defp append_string("") do
    ""
  end
  defp append_string(string) do
    " AND " <> string
  end

  defp atomize_keys(map) do
    Enum.reduce(map, [], fn({key, value}, acc) -> [ { String.to_atom(key), value } | acc] end)
  end

  def creds do
    struct(Cbclientapi, Application.get_env(:cbclientapi, :creds))
  end

  def trim_ok({:ok, val}) do
    val
  end
end

