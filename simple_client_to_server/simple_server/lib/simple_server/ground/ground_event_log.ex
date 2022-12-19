defmodule SimpleServer.Ground.GroundEventLog do
  @moduledoc false
  use Ecto.Schema

  @type event() :: any()
  @type event_data() :: binary()
  @type event_type() :: any()
  @type topic() :: {String.t(), non_neg_integer() | any(), binary()}
  @type offset() :: pos_integer()

  @primary_key false
  schema "ground_event_log" do
    field(:client_id, :string, primary_key: true)
    field(:instance_id, :integer, primary_key: true)
    field(:ingested_at, :utc_datetime_usec, primary_key: true)

    field(:event_type_id, :integer)
    field(:key, :binary)
    field(:offset, :integer)
    field(:event_timestamp, :integer)
    field(:event_data, :binary)
    field(:schema_version, :integer)
  end
end
