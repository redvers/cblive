require Logger
defmodule Cblclient.Master do
  defstruct creds: %Cbclientapi{}, sensorpids: HashDict.new

  def check_sensors do
    GenServer.cast(__MODULE__, :check_sensors)
  end

  def handle_cast(:check_sensors, state) do
    Logger.debug("Checking sensors for updates")
    {:ok, sensordata} = Cbclientapi.Sensor.search(state.creds)
    Enum.map(sensordata, &to_sensor_struct/1)
    |> Enum.filter(&sensor_changed?/1)
    |> Enum.map(&(notify_servers(&1, state.creds)))

    {:noreply, state}
  end

  def to_sensor_struct(map) do
    kv = Enum.reduce(map, [], fn({k,v}, acc) -> [ {String.to_atom(k), v} | acc ] end)
    struct(Cblclient.Proccache.Sensor, kv)
  end

  def sensor_changed?(sensorstruct) do
    case Cblclient.Proccache.Sensor.read!(sensorstruct.id) do
      nil          -> true
      mnesiasensor -> case mnesiasensor.last_update == sensorstruct.last_update do
                        true  -> false
                        false -> true
                      end
    end
  end

  def notify_servers(sensorstruct, creds) do
    case Supervisor.start_child(Cblclient.Sensor.Supervisor, [sensorstruct.id]) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
    |> Cblclient.Sensor.notify_change(creds, sensorstruct)
  end
















  def start_link do
    GenServer.start_link(__MODULE__, %Cblclient.Master{}, name: __MODULE__)
  end

  def init(state) do
    cbc = Application.get_env(:cbclientapi, :creds)
#    Logger.debug(inspect(cbc))
    cbclientapi = %Cbclientapi{
      api: Keyword.get(cbc, :api),
      hostname: (Keyword.get(cbc, :hostname)),
      port: Keyword.get(cbc, :port)}

    newstate = %Cblclient.Master{state | creds: cbclientapi}
    {:ok, newstate}
  end

end
