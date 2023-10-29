defmodule Testcontainers.EctoMysqlTest do
  use ExUnit.Case, async: true

  import Testcontainers.Ecto

  @moduletag timeout: 300_000

  test "can use ecto function" do
    {:ok, _container} =
      mysql_container(
        app: :testcontainers,
        migrations_path: "#{__DIR__}/support/migrations",
        repo: Testcontainers.MysqlRepo,
        port: 3336
      )

    {:ok, _pid} = Testcontainers.MysqlRepo.start_link()
    assert Testcontainers.MysqlRepo.all(Testcontainers.TestUser) == []
  end
end
