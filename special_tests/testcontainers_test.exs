defmodule TestcontainersTest do
  alias Testcontainers.Container.MySqlContainer
  use ExUnit.Case, async: true

  @moduletag timeout: 300_000

  test "will cleanup containers" do
    {:ok, container} = Testcontainers.start_container(MySqlContainer.new())
    GenServer.stop(Testcontainers)
    TestHelper.wait_for_genserver_state(Testcontainers, :down)
    {:ok, _} = Testcontainers.start_link()
    :ok = TestHelper.wait_for_lambda(fn -> with {:error, _} <- Testcontainers.get_container(container.container_id), do: :ok end, max_retries: 15, interval: 1000)
  end
end
