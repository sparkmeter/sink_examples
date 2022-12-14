defmodule SimpleServer.Repo.Migrations.InitialTables do
  use Ecto.Migration

  def change do
    create table(:sink_instance_ids, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:instance_id, :integer, null: false)

      timestamps(type: :utc_datetime_usec)
    end
  end
end
