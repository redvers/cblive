require Logger
defmodule Cblive.Router do
  use GenServer

  ## INCOMING NETCONN EVENT
  def handle_cast({:initial, netconn = %Cblstruct.Netconn{}}, state) do
    Logger.debug("Received initial via cast")

    {:ok, netconn}
    |> reject_localhost
    |> inspect
    |> Logger.debug




    {:noreply, state}
  end

  def reject_localhost({:drop, reason}) do
    {:drop, reason}
  end
  def reject_localhost({:ok, netconn = %Cblstruct.Netconn{}}) do
    case Cblstruct.Netconn.string_localv4(netconn) == "127.0.0.1" do
      true  -> {:drop, {"LocalIPv4 was 127.0.0.1", netconn}}
      false -> {:ok, netconn}
    end
  end



















  def start_link do
    GenServer.start_link(__MODULE__, nil, [])
  end

  def init(nil) do
    {:ok, nil}
  end

  def emit(pid) when is_pid(pid) do
    Logger.debug("Emit test packet")
    recv_netconn(pid, Cblstruct.Netconn.sample)
  end

  def recv_netconn(pid, netconn = %Cblstruct.Netconn{}) do
    Logger.debug("Sending via cast")
    GenServer.cast(pid, {:initial, netconn})
  end





#  emit
#  |> filter 127.0.0.1
#  |> tee(proca, procb)

end

