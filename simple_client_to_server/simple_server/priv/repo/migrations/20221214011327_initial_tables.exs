defmodule SimpleServer.Repo.Migrations.InitialTables do
  use Ecto.Migration

  def change do
    create table(:sink_instance_ids, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:instance_id, :integer, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create table(:sensors, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:name, :string, null: false)
      add(:serial_number, :string, null: false)
      add(:offset, :integer, null: false)

      timestamps(type: :utc_datetime_usec)
    end
    create index(:sensors, :serial_number, unique: true)

    create table(:sensor_configs, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:sensor_id, references(:sensors, type: :uuid), null: false)
      add(:on, :boolean, null: false)
      add(:offset, :integer, null: false)

      timestamps(type: :utc_datetime_usec)
    end
    create index(:sensor_configs, :sensor_id, unique: true)

    create table(:client_sensors, primary_key: false) do
      add(:id, :uuid, null: false, primary_key: true)
      add(:client_id, :string, null: false)
      add(:sensor_id, references(:sensors, type: :uuid), null: false)

      timestamps(type: :utc_datetime_usec)
    end
    create index(:client_sensors, :sensor_id, unique: true)


    create table(:cloud_event_log, primary_key: false) do
      add(:inserted_at, :utc_datetime_usec, null: false, primary_key: true)

      add(:key, :binary, null: false)
      add(:event_type_id, :integer, null: false)
      add(:offset, :integer, null: false)
      add(:event_timestamp, :integer, null: false)
      add(:schema_version, :integer, null: false)
      add(:event_data, :binary)
    end

    create table(:last_cloud_event_log_events, primary_key: false) do
      add :key, :binary, null: false, primary_key: true
      add :event_type_id, :integer, null: false, primary_key: true
      add :offset, :integer, null: false
      add :cloud_event_log_inserted_at, references(:cloud_event_log, column: :inserted_at, type: :utc_datetime_usec), null: false

      timestamps()
    end

    create table(:outgoing_event_subscriptions, primary_key: false) do
      add :client_id, :string, null: false, primary_key: true
      add :key, :binary, null: false, primary_key: true
      add :event_type_id, :integer, null: false, primary_key: true
      add :consumer_offset, :integer, null: false
      add :ack_at_row_id, :integer, null: true
      add :nack_at_row_id, :integer, null: true

      timestamps()
    end

    create table(:ack_log, primary_key: false) do
      add :client_id, :string, null: false, primary_key: true
      add :key, :binary, null: false, primary_key: true
      add :event_type_id, :integer, null: false, primary_key: true
      add :offset, :integer, primary_key: true

      timestamps(updated_at: false)
    end

    execute(
      """
      CREATE OR REPLACE FUNCTION write_last_cloud_event()
        RETURNS trigger AS
      $$
      BEGIN
        INSERT INTO last_cloud_event_log_events(key, event_type_id, "offset", cloud_event_log_inserted_at, updated_at, inserted_at)
        VALUES(NEW.key, NEW.event_type_id, NEW.offset, NEW.inserted_at, DATETIME('now'), DATETIME('now'))
        ON CONFLICT(key, event_type_id) DO UPDATE SET
        key=NEW.key,
        event_type_id=NEW.event_type_id,
        "offset"=NEW.offset,
        cloud_event_log_inserted_at=NEW.inserted_at,
        updated_at=DATETIME('now')
        WHERE "offset" < NEW.offset;

        RETURN NEW;
      END;
      $$
      LANGUAGE 'plpgsql';
      """,
      ""
    )

    execute(
      """
      CREATE TRIGGER last_cloud_event_trigger
      AFTER INSERT
      ON cloud_event_log
      FOR EACH ROW
      EXECUTE PROCEDURE write_last_cloud_event();
      """,
      ""
    )
  end
end
