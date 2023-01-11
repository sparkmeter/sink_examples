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

    create table(:last_ground_log_events, options: "WITHOUT ROWID", primary_key: false) do
      add :key, :binary, null: false, primary_key: true
      add :event_type_id, :integer, null: false, primary_key: true
      add :offset, :integer, null: false
      add :ground_event_log_id, references(:ground_event_logs), null: false

      timestamps()
    end

    create table(:last_sensor_readings, options: "WITHOUT ROWID", primary_key: false) do
      add :name, :string, primary_key: true
      add :offset, :integer, null: false
      add :temperature, :integer, null: false
      add :humidity, :integer, null: false

      timestamps()
    end

    create table(:outgoing_event_subscriptions, options: "WITHOUT ROWID", primary_key: false) do
      add :key, :binary, null: false, primary_key: true
      add :event_type_id, :integer, null: false, primary_key: true
      add :consumer_offset, :integer, null: false
      add :ack_at_row_id, :integer, null: true
      add :nack_at_row_id, :integer, null: true

      timestamps()
    end

    create table(:sink_instance_ids) do
      add(:client_instance_id, :integer, null: false)
      add(:server_instance_id, :integer, null: true)

      timestamps(type: :utc_datetime_usec)
    end

    execute(
      """
      CREATE TRIGGER last_ground_log_event
        AFTER INSERT ON ground_event_logs
      BEGIN
        INSERT INTO last_ground_log_events
        VALUES(new.key, new.event_type_id, new.offset, new.id, DATETIME('now'), DATETIME('now'))
        ON CONFLICT(key, event_type_id) DO UPDATE SET
        key=new.key,
        event_type_id=new.event_type_id,
        offset=new.offset,
        ground_event_log_id=new.id,
        updated_at=DATETIME('now')
        WHERE offset < new.offset;
      END;
      """,
      ""
    )
  end
end
