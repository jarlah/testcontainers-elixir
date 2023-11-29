# SPDX-License-Identifier: MIT
defmodule Testcontainers.Docker.Api do
  @moduledoc """
  Internal docker api. Only for direct use by `Testcontainers`
  """

  alias DockerEngineAPI.Model.ContainerCreateRequest
  alias DockerEngineAPI.Api
  alias Testcontainers.Container

  def get_container(container_id, conn)
      when is_binary(container_id) do
    case Api.Container.container_inspect(conn, container_id) do
      {:error, %Tesla.Env{status: other}} ->
        {:error, {:http_error, other}}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{} = error} ->
        {:error, {:failed_to_get_container, error}}

      {:ok, response} ->
        {:ok, from(response)}
    end
  end

  def pull_image(image, conn) when is_binary(image) do
    case Api.Image.image_create(conn, fromImage: image) do
      {:ok, %Tesla.Env{status: 200}} ->
        {:ok, nil}

      {:error, %Tesla.Env{status: other}} ->
        {:error, {:http_error, other}}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{} = error} ->
        {:error, {:failed_to_pull_image, error}}
    end
  end

  def create_container(%Container{} = container, conn) do
    case Api.Container.container_create(conn, container_create_request(container)) do
      {:error, %Tesla.Env{status: other}} ->
        {:error, {:http_error, other}}

      {:ok, %{Id: id}} ->
        {:ok, id}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{} = error} ->
        {:error, {:failed_to_create_container, error}}
    end
  end

  def start_container(id, conn) when is_binary(id) do
    case Api.Container.container_start(conn, id) do
      {:ok, %Tesla.Env{status: 204}} ->
        :ok

      {:error, %Tesla.Env{status: other}} ->
        {:error, {:http_error, other}}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{} = error} ->
        {:error, {:failed_to_start_container, error}}
    end
  end

  def stop_container(container_id, conn) when is_binary(container_id) do
    with {:ok, _} <- Api.Container.container_kill(conn, container_id),
         {:ok, _} <- Api.Container.container_delete(conn, container_id) do
      :ok
    end
  end

  def put_files(container_id, connection, path, file_contents) do
    with {:ok, temp_file} <- write_temp_file(file_contents),
         {:ok, tar_stream} <- create_tar_stream(temp_file) do
      Api.Container.put_container_archive(connection, container_id, path, tar_stream)
    else
      {:error, reason} ->
        IO.puts("Failed to create TAR stream: #{reason}")
        {:error, reason}
    end
  end

  # Helper function to write file contents to a temporary file
  defp write_temp_file(contents) do
    temp_file = "/tmp/#{UUID.uuid4()}.tmp"

    case File.write(temp_file, contents) do
      :ok ->
        {:ok, temp_file}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper function to create a tar stream from a file
  defp create_tar_stream(file_path) do
    tar_file = "#{file_path}.tar"
    # file_path must be charlist ref https://til.kaiwern.com/tags/88
    :ok = :erl_tar.create(tar_file, [String.to_charlist(file_path)], [:write, :compressed])
    {:ok, File.stream!(tar_file)}
  end

  def inspect_exec(exec_id, conn) do
    case DockerEngineAPI.Api.Exec.exec_inspect(conn, exec_id) do
      {:ok, %DockerEngineAPI.Model.ExecInspectResponse{} = body} ->
        {:ok, parse_inspect_result(body)}

      {:ok, %Tesla.Env{status: status}} ->
        {:error, {:http_error, status}}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{message: message}} ->
        {:error, message}

      {:error, message} ->
        {:error, message}
    end
  end

  def start_exec(container_id, command, conn) do
    with {:ok, exec_id} <- create_exec(container_id, command, conn),
         :ok <- start_exec(exec_id, conn) do
      {:ok, exec_id}
    end
  end

  def stdout_logs(container_id, conn) do
    case DockerEngineAPI.Api.Container.container_logs(
           conn,
           container_id,
           stdout: true,
           stderr: true
         ) do
      {:ok, %Tesla.Env{body: body}} ->
        {:ok, body}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{message: message}} ->
        {:error, message}

      {:error, message} ->
        {:error, message}
    end
  end

  def get_bridge_gateway(conn) do
    case DockerEngineAPI.Api.Network.network_inspect(conn, "bridge") do
      {:ok, %DockerEngineAPI.Model.Network{IPAM: %DockerEngineAPI.Model.Ipam{Config: config}}} ->
        with_gateway =
          config
          |> Enum.filter(fn cfg -> Map.get(cfg, :Gateway, nil) != nil end)

        if length(with_gateway) > 0 do
          gateway = with_gateway |> Kernel.hd() |> Map.get(:Gateway)
          {:ok, gateway}
        else
          {:error, :no_gateway}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_inspect_result(%DockerEngineAPI.Model.ExecInspectResponse{} = json) do
    %{running: json."Running", exit_code: json."ExitCode"}
  end

  defp container_create_request(%Container{} = container_config) do
    %ContainerCreateRequest{
      Image: container_config.image,
      Cmd: container_config.cmd,
      ExposedPorts: map_exposed_ports(container_config),
      Env: map_env(container_config),
      Labels: container_config.labels,
      HostConfig: %{
        AutoRemove: container_config.auto_remove,
        PortBindings: map_port_bindings(container_config),
        Privileged: container_config.privileged,
        Binds: map_binds(container_config),
        Mounts: map_volumes(container_config)
      }
    }
  end

  defp map_exposed_ports(%Container{} = container_config) do
    container_config.exposed_ports
    |> Enum.map(fn
      {container_port, _host_port} -> {container_port, %{}}
      port -> {port, %{}}
    end)
    |> Enum.into(%{})
  end

  defp map_env(%Container{} = container_config) do
    container_config.environment
    |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
  end

  defp map_port_bindings(%Container{} = container_config) do
    container_config.exposed_ports
    |> Enum.map(fn
      {container_port, host_port} ->
        {container_port, [%{"HostIp" => "0.0.0.0", "HostPort" => to_string(host_port)}]}

      port ->
        {port, [%{"HostIp" => "0.0.0.0", "HostPort" => ""}]}
    end)
    |> Enum.into(%{})
  end

  defp map_binds(%Container{} = container_config) do
    container_config.bind_mounts
    |> Enum.map(fn volume_binding ->
      "#{volume_binding.host_src}:#{volume_binding.container_dest}:#{volume_binding.options}"
    end)
  end

  defp map_volumes(%Container{} = container_config) do
    container_config.bind_volumes
    |> Enum.map(fn volume_to_dest ->
      %{
        Target: volume_to_dest.container_dest,
        Source: volume_to_dest.volume,
        Type: "volume",
        ReadOnly: volume_to_dest.read_only
      }
    end)
  end

  defp from(%DockerEngineAPI.Model.ContainerInspectResponse{
         Id: container_id,
         Image: image,
         NetworkSettings: %{Ports: ports},
         Config: %{Env: env, Labels: labels}
       }) do
    %Container{
      container_id: container_id,
      image: image,
      labels: labels,
      exposed_ports:
        Enum.reduce(ports || [], [], fn {key, ports}, acc ->
          acc ++
            Enum.map(ports || [], fn %{"HostPort" => host_port} ->
              {key |> String.replace("/tcp", "") |> String.to_integer(),
               host_port |> String.to_integer()}
            end)
        end),
      environment:
        Enum.reduce(env || [], %{}, fn env, acc ->
          tokens = String.split(env, "=")
          Map.merge(acc, %{"#{List.first(tokens)}": List.last(tokens)})
        end)
    }
  end

  defp create_exec(container_id, command, conn) do
    data = %{"Cmd" => command}

    case DockerEngineAPI.Api.Exec.container_exec(conn, container_id, data) do
      {:ok, %DockerEngineAPI.Model.IdResponse{Id: id}} ->
        {:ok, id}

      {:ok, %Tesla.Env{status: status}} ->
        {:error, {:http_error, status}}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{message: message}} ->
        {:error, message}

      {:error, message} ->
        {:error, message}
    end
  end

  defp start_exec(exec_id, conn) do
    case DockerEngineAPI.Api.Exec.exec_start(conn, exec_id, body: %{}) do
      {:ok, %Tesla.Env{status: 200}} ->
        :ok

      {:ok, %Tesla.Env{status: status}} ->
        {:error, {:http_error, status}}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{message: message}} ->
        {:error, message}

      {:error, message} ->
        {:error, message}
    end
  end
end
