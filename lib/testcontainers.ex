defmodule Testcontainers do
  use GenServer

  @moduledoc """
  The main entry point into Testcontainers.

  This is a GenServer that needs to be started before anything can happen.
  """

  defstruct []

  alias Testcontainers.WaitStrategy
  alias Testcontainers.Logger
  alias Testcontainers.Docker.Api
  alias Testcontainers.Connection
  alias Testcontainers.Container
  alias Testcontainers.ContainerBuilder

  import Testcontainers.Constants

  @timeout 300_000

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl true
  def init(options \\ []) do
    send(self(), :load)
    {:ok, %{options: options}}
  end

  @doc """
  Starts a new container based on the provided configuration, applying any specified wait strategies.

  This function performs several steps:
  1. Pulls the necessary Docker image.
  2. Creates and starts a container with the specified configuration.
  3. Registers the container with a reaper process for automatic cleanup, ensuring it is stopped and removed when the current process exits or in case of unforeseen failures.

  ## Parameters

  - `config`: A `%Container{}` struct containing the configuration settings for the container, such as the image to use, environment variables, bound ports, and volume bindings.
  - `options`: Optional keyword list. Supports the following options:
    - `:on_exit`: A callback function that's invoked when the current process exits. It receives a no-argument callable (often a lambda) that executes cleanup actions, such as stopping the container. This callback enhances the reaper's functionality by providing immediate cleanup actions at the process level, while the reaper ensures that containers are ultimately cleaned up in situations like abrupt process termination. It's especially valuable in test environments, complementing ExUnit's `on_exit` for resource cleanup after tests.

  ## Examples

      iex> config = %Container{
            image: "mysql:latest",
            wait_strategies: [CommandWaitStrategy.new(["bash", "sh", "command_that_returns_0_exit_code"])]
          }
      iex> {:ok, container} = Container.run(config)

  ## Returns

  - `{:ok, container}` if the container is successfully created, started, and passes all wait strategies.
  - An error tuple, such as `{:error, reason}`, if there is a failure at any step in the process.

  ## Notes

  - The container is automatically registered with a reaper process, ensuring it is stopped and removed when the current process exits, or in the case of unforeseen failures.
  - It's important to specify appropriate wait strategies to ensure the container is fully ready for interaction, especially for containers that may take some time to start up services internally.

  """
  def start_container(config_builder, options \\ []) do
    wait_for_call({:start_container, config_builder, options})
  end

  @doc """
  Stops a running container.

  This sends a stop command to the specified container. The Docker daemon terminates the container process gracefully.

  ## Parameters

  - `container_id`: The ID of the container to stop, as a string.

  ## Returns

  - `:ok` if the container stops successfully.
  - `{:error, reason}` on failure.

  ## Examples

      :ok = Testcontainers.Connection.stop_container("my_container_id")
  """
  def stop_container(container_id) when is_binary(container_id) do
    wait_for_call({:stop_container, container_id})
  end

  @doc """
  Retrieves the stdout logs from a specified container.

  Useful for debugging and monitoring, this function collects the logs that have been written to stdout within the container.

  ## Parameters

  - `container_id`: The ID of the container, as a string.

  ## Returns

  - `{:ok, logs}` where `logs` is the content that has been written to stdout in the container.
  - `{:error, reason}` on failure.

  ## Examples

      {:ok, logs} = Testcontainers.Connection.stdout_logs("my_container_id")
  """
  def stdout_logs(container_id) when is_binary(container_id) do
    wait_for_call({:stdout_logs, container_id})
  end

  @doc """
  Creates a new execution context in a running container and runs the specified command.

  This function is used to execute a one-off command within the context of the container.

  ## Parameters

  - `container_id`: The ID of the container, as a string.
  - `command`: A list of strings representing the command and its arguments to run in the container.

  ## Returns

  - `{:ok, exec_id}` which is an identifier for the executed command, useful for further inspection or interaction.
  - `{:error, reason}` on failure.

  ## Examples

      {:ok, exec_id} = Testcontainers.Connection.exec_create("my_container_id", ["ls", "-la"])
  """
  def exec_create(container_id, command) when is_binary(container_id) and is_list(command) do
    wait_for_call({:exec_create, command, container_id})
  end

  @doc """
  Initiates the execution of a previously created command in a running container.

  This function is used after `exec_create/2` to start the execution of the command within the container context.

  ## Parameters

  - `exec_id`: A string representing the unique identifier of the command to be executed (obtained from `exec_create/2`).

  ## Returns

  - `:ok` if the command execution started successfully.
  - `{:error, reason}` on failure.

  ## Examples

      :ok = Testcontainers.Connection.exec_start("my_exec_id")
  """
  def exec_start(exec_id) when is_binary(exec_id) do
    wait_for_call({:exec_start, exec_id})
  end

  @doc """
  Retrieves detailed information about a specific exec command.

  It's particularly useful for obtaining the exit status and other related data after a command has been executed in a container.

  ## Parameters

  - `exec_id`: A string representing the unique identifier of the executed command (obtained from `exec_create/2`).

  ## Returns

  - `{:ok, %{running: _, exit_code: _}}` with information about running state and exit code.
  - `{:error, reason}` on failure.

  ## Examples

      {:ok, exec_info} = Testcontainers.Connection.exec_inspect("my_exec_id")
  """
  def exec_inspect(exec_id) when is_binary(exec_id) do
    wait_for_call({:exec_inspect, exec_id})
  end

  def handle_info(:load, state) do
    conn = Connection.get_connection(state.options)

    session_id =
      :crypto.hash(:sha, "#{inspect(self())}#{DateTime.utc_now() |> DateTime.to_string()}")
      |> Base.encode16()

    ryuk_config = ContainerBuilder.build(%__MODULE__{}, on_exit: nil)

    with :ok <- Api.pull_image(ryuk_config.image, conn),
         {:ok, id} <- Api.create_container(ryuk_config, conn),
         :ok <- Api.start_container(id, conn),
         {:ok, container} <- Api.get_container(id, conn),
         {:ok, socket} <- create_ryuk_socket(container),
         :ok <- register_ryuk_filter(session_id, socket) do
      Logger.log("Testcontainers initialized")
      {:noreply, %{socket: socket, conn: conn, session_id: session_id}}
    else
      error ->
        {:stop, error, state}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:start_container, config_builder, options}, from, state) do
    Task.async(fn -> GenServer.reply(from, start_and_wait(config_builder, options, state.conn)) end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:stop_container, container_id}, from, state) do
    Task.async(fn -> GenServer.reply(from, Api.stop_container(container_id, state.conn)) end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:stdout_logs, container_id}, from, state) do
    Task.async(fn -> GenServer.reply(from, Api.stdout_logs(container_id, state.conn)) end)
    {:noreply, state}
  end

  # TODO combine exec_create and exec_start, into one operation
  # plus, send in Container struct and not container_id
  @impl true
  def handle_call({:exec_create, command, container_id}, from, state) do
    Task.async(fn -> GenServer.reply(from, Api.create_exec(container_id, command, state.conn)) end)

    {:noreply, state}
  end

  @impl true
  def handle_call({:exec_start, exec_id}, from, state) do
    Task.async(fn -> GenServer.reply(from, Api.start_exec(exec_id, state.conn)) end)
    {:noreply, state}
  end

  @impl true
  def handle_call({:exec_inspect, exec_id}, from, state) do
    Task.async(fn -> GenServer.reply(from, Api.inspect_exec(exec_id, state.conn)) end)
    {:noreply, state}
  end

  # private functions

  defp wait_for_call(call) do
    GenServer.call(__MODULE__, call, @timeout)
  end

  defp create_ryuk_socket(%Container{} = container) do
    host_port = Container.mapped_port(container, 8080)

    :gen_tcp.connect(~c"localhost", host_port, [
      :binary,
      active: false,
      packet: :line
    ])
  end

  defp register_ryuk_filter(value, socket) do
    :gen_tcp.send(
      socket,
      "label=#{container_sessionId_label()}=#{value}&" <>
        "label=#{container_version_label()}=#{library_version()}&" <>
        "label=#{container_lang_label()}=#{container_lang_value()}&" <>
        "label=#{container_label()}=#{true}\n"
    )

    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, "ACK\n"} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_and_wait(config_builder, options, state) do
    config = ContainerBuilder.build(config_builder, options)
    wait_strategies = config.wait_strategies || []

    with :ok <- Api.pull_image(config.image, state.conn),
          {:ok, id} <- Api.create_container(
            config
            |> Container.with_label(container_sessionId_label(), state.session_id)
            |> Container.with_label(container_version_label(), library_version())
            |> Container.with_label(container_lang_label(), container_lang_value())
            |> Container.with_label(container_label(), "#{true}"),
            state.conn
          ),
          :ok <- Api.start_container(id, state.conn),
          :ok <- wait_for_container(id, wait_strategies) do
      Api.get_container(id, state.conn)
    end
  end

  defp wait_for_container(id, wait_strategies) when is_binary(id) do
    Enum.reduce(wait_strategies, :ok, fn
      wait_strategy, :ok ->
        WaitStrategy.wait_until_container_is_ready(wait_strategy, id)

      _, error ->
        error
    end)
  end

  defimpl ContainerBuilder do
    @spec build(%Testcontainers{}, keyword()) :: %Container{}
    @impl true
    def build(_, _) do
      Container.new("testcontainers/ryuk:0.5.1")
      |> Container.with_exposed_port(8080)
      |> Container.with_environment("RYUK_PORT", "8080")
      |> Container.with_bind_mount("/var/run/docker.sock", "/var/run/docker.sock", "rw")
    end
  end
end
