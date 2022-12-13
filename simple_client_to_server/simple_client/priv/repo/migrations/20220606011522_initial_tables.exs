defmodule SimpleClient.Repo.Migrations.InitialTables do
  use Ecto.Migration

  def change do
    create table(:ground_event_logs, primary_key: true) do
      add :key, :binary, null: false
      add :event_type_id, :integer, null: false
      add :offset, :integer, null: false
      add :timestamp, :integer, null: false
      add :schema_version, :integer
      add :event_data, :binary
    end
    create unique_index(:ground_event_logs, [:key, :event_type_id, :offset])

    create table(:last_sensor_readings, primary_key: false) do
      add :name, :string, primary_key: true
      add :offset, :integer, null: false
      add :temperature, :integer, null: false
      add :humidity, :integer, null: false

      timestamps()
    end

    create table(:ack_logs, primary_key: true) do
      timestamps(updated_at: false)
    end

    create table(:sink_instance_ids) do
      add(:client_instance_id, :integer, null: false)
      add(:server_instance_id, :integer, null: true)

      timestamps(type: :utc_datetime_usec)
    end
  end
end
