defmodule SimpleClient.Repo do
  @moduledoc """
  A standard Ecto repo module.

  Exposes functionality to stand up and migrate the database.
  """
  use Ecto.Repo, otp_app: :simple_client, adapter: Ecto.Adapters.SQLite3

  @doc """
  Ensure that the database exists and is migrated.
  """
  @spec setup_db!() :: :ok
  def setup_db! do
    repos = Application.get_env(:simple_client, :ecto_repos)

    for repo <- repos do
      _ = setup_repo!(repo)
      _ = migrate_repo!(repo)
    end

    :ok
  end

  defp setup_repo!(repo) do
    db_file = Application.get_env(:simple_client, repo)[:database]

    unless File.exists?(db_file) do
      :ok = repo.__adapter__.storage_up(repo.config)
    end
  end

  defp migrate_repo!(repo) do
    Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
  end
end
