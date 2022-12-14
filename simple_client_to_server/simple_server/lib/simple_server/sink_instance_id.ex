defmodule SimpleServer.SinkInstanceId do
  @moduledoc """
  Track the client and server instance ids.

  There should only ever be one record in this table.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @primary_key {:id, :string, []}
  schema "sink_instance_ids" do
    field(:instance_id, :integer)

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = instance_id, params) do
    instance_id
    |> cast(params, [:instance_id])
    |> validate_required([:instance_id])
  end
end
