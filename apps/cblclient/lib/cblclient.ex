require Logger
defmodule Cblclient do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    :mnesia.table_info(:schema, :storage_type) |> validate_or_create_dbschema
    validate_or_create_table(Cblclient.Proccache.Pollstate)
    validate_or_create_table(Cblclient.Proccache.Counts)
    validate_or_create_table(Cblclient.Proccache.Sensor)
    validate_or_create_table(Cblclient.Proccache.Summary)
    validate_or_create_table(Cblclient.Proccache.Full)

    validate_or_create_table(Cblclient.Proccache.Filemod)
    validate_or_create_table(Cblclient.Proccache.Netconn)

    children = [
      # Define workers and child supervisors to be supervised
      worker(Cblclient.Master, []),
      supervisor(Cblclient.Sensor.Supervisor, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cblclient.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def validate_or_create_table(tablename) do
    case tablename in Amnesia.info(:tables) do
      false -> Logger.debug(inspect(tablename))
        apply(tablename, :create!, [[disk: [node]]])
      true -> :ok
    end
  end


  def validate_or_create_dbschema(:ram_copies) do
    Logger.debug("mnesia schema is in ram - writing to disk")
    Amnesia.stop
    Amnesia.Schema.destroy
    Amnesia.Schema.create
    Amnesia.start
    :disc_copies = :mnesia.table_info(:schema, :storage_type) # match or die!
  end
  def validate_or_create_dbschema(:disc_copies) do
  end


end
