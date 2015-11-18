require Logger
defmodule Cblclient.Sensor do
  use GenServer

  def notify_change(pid, creds, sensorstruct) do
    GenServer.cast(pid, {:notify_change, creds, sensorstruct})
  end




  def handle_cast({:notify_change, creds, sensorstruct}, state) do
    ss = generate_search_string(sensorstruct)

    webstruct = Cbclientapi.Process.search(creds, {ss, 1000})
    |> handle_proclist_search

    inspect(webstruct) |> Logger.debug

    Enum.map(webstruct, fn(x) -> case Cblclient.Proccache.Counts.read!(x.guid) do
                                           nil -> Logger.debug("Nothing in cache - do full data #{x.guid}")
#                                                  fulldata(webstruct,0) # do v2 and do thang from index 0
                                   amnesiaproc -> Logger.debug("Entry exists in cache, compare stats: #{x.netconn} to #{amnesiaproc.netconn}")
                                 end end)


    ## Compare netconn_cnt to that in mnesia
    ## If changed, emit event
    {:noreply, state}
  end

  def handle_proclist_search({:ok, %{"total_results" => 0}}) do
    Logger.debug("No processes here, return empty list")
    []
  end

  def handle_proclist_search({:ok, %{"total_results" => count, "results" => results}}) do
    Enum.map(results, &process_process/1)
  end

  def process_process(process = %{"unique_id" => unique_id, "last_update" => last_update, "hostname" => hostname}) do
    childproc_count = Map.get(process, "childproc_count", 0)
    modload_count   = Map.get(process, "modload_count", 0)
    regmod_count    = Map.get(process, "regmod_count", 0)
    filemod_count   = Map.get(process, "filemod_count", 0)
    netconn_count   = Map.get(process, "netconn_count", 0)
    crossproc_count = Map.get(process, "crossproc_count", 0)
    terminated      = Map.get(process, "terminated", false)

    queried_count = %Cblclient.Proccache.Counts{guid: unique_id, last_update: last_update, modload: modload_count, crossproc: crossproc_count,
                                                filemod: filemod_count, regmod: regmod_count, emet: 0, netconn: netconn_count,
                                                childproc: childproc_count, terminated: terminated}
  end






  def generate_search_string(sensorstruct) do
    "sensor_id:" <> Integer.to_string(sensorstruct.id)
    <> " AND " <> from_event_time(sensorstruct)
    <> " AND " <> "netconn_count:[1 TO *]"
  end

  def from_event_time(sensorstruct) do
    case Cblclient.Proccache.Sensor.read!(sensorstruct.id) do
      nil -> 
      qt = Timex.Date.now
#      st = Timex.Date.subtract(qt, {0, 86400, 0})
      st = Timex.Date.subtract(qt, {0, 1000, 0})

      "last_update:[" <> Timex.DateFormat.format!(st, "{YYYY}-{0M}-{0D}T{h24}:{m}:{s}")
      <> " TO "       <> Timex.DateFormat.format!(qt, "{YYYY}-{0M}-{0D}T{h24}:{m}:{s}")
      <> "]"
    end
  end



  def start_link(sensorid) do
    GenServer.start_link(__MODULE__, sensorid, name: String.to_atom("SensorID:" <> Integer.to_string(sensorid)))
  end

  def init(sensorid) do
    {:ok, sensorid}
  end

end
