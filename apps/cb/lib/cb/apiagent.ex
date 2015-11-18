require Logger
defmodule CB.APIAgent do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, HashDict.new, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:psearch, string}, from, state) do
    pcount = get_process_count(string)
    Logger.debug("#{pcount} processes found")
    reflist = div(pcount, 100)
    |> Range.new(0)
    |> Enum.reduce([], fn(pagenum, acc) -> [psearchpage(pagenum, string) | acc] end)
    |> Enum.map(&trim_ok/1)

    byfromhash = HashDict.get(state, :inflight, HashDict.new)
    |> HashDict.put(from, reflist)

    newstate = HashDict.put(state, :inflight, byfromhash)

    GenServer.reply(from, byfromhash)
#    {:noreply, byfromhash, newstate}
    {:noreply, newstate}
  end

  def trim_ok({:ok, term}) do
    term
  end

  def handle_info({:hackney_response, ref, {:status, 200, "OK"}}, state) do
    {:noreply, state}
  end
  def handle_info({:hackney_response, ref, {:headers, _}}, state) do
    {:noreply, state}
  end
  def handle_info({:hackney_response, ref, string}, state) when is_binary(string) do
    {:noreply, state}
  end
  def handle_info({:hackney_response, ref, :done}, state) do
    



    {:noreply, state}
  end


  def get_process_count(string) do
    url = "https://#{CB.creds.hostname}:#{CB.creds.port}/api/v1/process?q=#{:hackney_url.urlencode(string)}&rows=0"
    case :hackney.get(url, [{"X-Auth-Token", CB.creds.api}], '', [ssl_options: [ insecure: true]]) do
      {:ok, 200, headers, bodyref} -> :hackney.body(bodyref)
                                      |> decode_json
                                      |> extract_count
      badthings                    -> {:error, badthings}
    end
  end

  def psearchpage(pagenum, string) do
    "https://#{CB.creds.hostname}:#{CB.creds.port}/api/v1/process?q=#{:hackney_url.urlencode(string)}&rows=100&start=#{pagenum*100}"
    |> :hackney.get([{"X-Auth-Token", CB.creds.api}], '', [ssl_options: [insecure: true], async: :true]) #|> inspect |> Logger.debug

  end



  def decode_json({:ok, json}) do
    JSX.decode(json)
  end

  def extract_count({:ok, %{"total_results" => total_results}}) do
    total_results
  end
end
