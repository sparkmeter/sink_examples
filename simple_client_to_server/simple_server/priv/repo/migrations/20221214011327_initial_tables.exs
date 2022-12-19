defmodule SimpleServer.Repo.Migrations.InitialTables do
  use Ecto.Migration

  def change do
    create table(:sink_instance_ids, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:instance_id, :integer, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    # these tables are for event processing

    create table(:ground_event_log, primary_key: false) do
      add(:client_id, :string, null: false, primary_key: true)
      add(:instance_id, :integer, null: false, primary_key: true)
      add(:ingested_at, :utc_datetime_usec, null: false, primary_key: true)

      add(:key, :binary, null: false)
      add(:event_type_id, :integer, null: false)
      add(:offset, :integer, null: false)
      add(:event_timestamp, :integer, null: false)
      add(:schema_version, :integer, null: false)
      add(:event_data, :binary)
    end
    # todo: add secondary index on ground_event_log for key, event_type_id, offset

    create table(:ground_event_log_producer_offsets, primary_key: false) do
      add(:client_id, :string, null: false, primary_key: true)
      add(:instance_id, :integer, null: false, primary_key: true)
      add(:key, :binary, null: false, primary_key: true)
      add(:event_type, :string, null: false, primary_key: true)
      add(:producer_offset, :integer, null: false)
      add(:ingested_at, :utc_datetime_usec, null: false)
    end

    create table(:incoming_event_subscriptions, primary_key: false) do
      add(:client_id, :string, null: false, primary_key: true)
      add(:instance_id, :integer, null: false, primary_key: true)
      add(:key, :binary, null: false, primary_key: true)
      add(:event_type, :string, null: false, primary_key: true)
      add(:consumer_offset, :integer, null: false)
      add(:ingested_at, :utc_datetime_usec, null: false)
      # should we have a column for nack, ex: blocked_by_nack and columns with data about the nack?
    end
  end
end
