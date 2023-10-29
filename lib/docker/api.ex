# SPDX-License-Identifier: MIT
defmodule Testcontainers.Docker.Api do
  alias DockerEngineAPI.Model.ContainerCreateRequest
  alias DockerEngineAPI.Api
  alias Testcontainers.Container

  def get_container(container_id, conn)
      when is_binary(container_id) do
    with {:ok, response} <-
           Api.Container.container_inspect(conn, container_id)
           |> parse_docker_response() do
      {:ok, from(response)}
    end
  end

  def pull_image(image, conn) when is_binary(image) do
    Api.Image.image_create(conn, fromImage: image)
    |> parse_docker_response()
  end

  @spec create_container(%Container{}, Tesla.Env.client()) :: {:ok, binary()} | {:error, any()}
  def create_container(%Container{} = container, conn) do
    with {:ok, %{Id: id}} <-
           Api.Container.container_create(conn, container_create_request(container))
           |> parse_docker_response() do
      {:ok, id}
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

  def create_exec(container_id, command, conn) do
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

  def start_exec(exec_id, conn) do
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

  def stdout_logs(container_id, conn) do
    case DockerEngineAPI.Api.Container.container_logs(conn, container_id, stdout: true) do
      {:ok, %Tesla.Env{body: body}} ->
        {:ok, body}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{message: message}} ->
        {:error, message}

      {:error, message} ->
        {:error, message}
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
        Binds: map_binds(container_config)
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

  defp from(
         %DockerEngineAPI.Model.ContainerInspectResponse{
           Id: container_id,
           Image: image,
           NetworkSettings: %{Ports: ports}
         } = res
       ) do
    %Container{
      container_id: container_id,
      image: image,
      exposed_ports:
        Enum.reduce(ports || [], [], fn {key, ports}, acc ->
          acc ++
            Enum.map(ports || [], fn %{"HostPort" => host_port} ->
              {key |> String.replace("/tcp", "") |> String.to_integer(),
               host_port |> String.to_integer()}
            end)
        end),
      environment:
        Enum.reduce(res."Config"."Env" || [], %{}, fn env, acc ->
          tokens = String.split(env, "=")
          Map.merge(acc, %{"#{List.first(tokens)}": List.last(tokens)})
        end)
    }
  end

  defp parse_docker_response(docker_response) do
    case docker_response do
      {:error, %Tesla.Env{status: other}} ->
        {:error, {:http_error, other}}

      {:ok, %DockerEngineAPI.Model.ErrorResponse{} = error} ->
        {:error, error}

      {:ok, response} ->
        {:ok, response}
    end
  end
end
