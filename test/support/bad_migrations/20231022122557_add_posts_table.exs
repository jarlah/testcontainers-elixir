defmodule Testcontainers.Repo.Migrations.AddPostsTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:email, :stringa, null: false)
      add(:hashed_password, :string, null: false)
      add(:confirmed_at, :naive_datetime)
      timestamps()
    end
  end
end
