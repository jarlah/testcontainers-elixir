# SPDX-License-Identifier: MIT
# Original by: Marco Dallagiacoma @ 2023 in https://github.com/dallagi/excontainers
# Modified by: Jarl André Hübenthal @ 2023
defmodule Testcontainers.Container.RedisContainer do
  @moduledoc """
  Provides functionality for creating and managing Redis container configurations.

  This module includes helper methods for setting up a Redis container with specific parameters such as image and more.
  """

  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container
  alias Testcontainers.WaitStrategy.CommandWaitStrategy
  alias Testcontainers.Container.RedisContainer

  @default_image "redis"
  @default_tag "7.2"
  @default_port 6379
  @wait_timeout 60_000

  defstruct image: "#{@default_image}:#{@default_tag}",
            wait_timeout: @wait_timeout,
            port: @default_port

  @doc """
  Creates a new `RedisContainer` struct with default configurations.
  """
  def new, do: %__MODULE__{}

  @doc """
  Overrides the default image used for the Redis container.

  ## Examples

      iex> config = RedisContainer.new()
      iex> new_config = RedisContainer.with_image(config, "redis:xyz")
      iex> new_config.image
      "redis:xyz"
  """
  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  @doc """
  Overrides the default port used for the Redis container.

  Note: this will not change what port the docker container is listening to internally.

  ## Examples

      iex> config = RedisContainer.new()
      iex> new_config = RedisContainer.with_port(config, 1111)
      iex> new_config.port
      1111
  """
  def with_port(%__MODULE__{} = config, port) when is_integer(port) do
    %{config | port: port}
  end

  @doc """
  Overrides the default wait timeout used for the Redis container.

  Note: this timeout will be used for each individual wait strategy.

  ## Examples

      iex> config = RedisContainer.new()
      iex> new_config = RedisContainer.with_wait_timeout(config, 8000)
      iex> new_config.wait_timeout
      8000
  """
  def with_wait_timeout(%__MODULE__{} = config, wait_timeout) when is_integer(wait_timeout) do
    %{config | wait_timeout: wait_timeout}
  end

  @doc """
  Retrieves the default Docker image for the Redis container.
  """
  def default_image, do: @default_image

  @doc """
  Returns the port on the _host machine_ where the Redis container is listening.
  """
  def port(%Container{} = container), do: Container.mapped_port(container, @default_port)

  @doc """
  Generates the connection URL for accessing the Redis service running within the container.

  This URL is based on the standard localhost IP and the mapped port for the container.

  ## Parameters

  - `container`: The active Redis container instance in the form of a %Container{} struct.

  ## Examples

      iex> RedisContainer.connection_url(container)
      "http://localhost:32768" # This value will be different depending on the mapped port.
  """
  def connection_url(%Container{} = container), do: "redis://localhost:#{port(container)}/"

  defimpl ContainerBuilder, for: __MODULE__ do
    import Container

    @doc """
    Implementation of the `ContainerBuilder` protocol specific to `RedisContainer`.

    This function builds a new container configuration, ensuring the Redis image is compatible, setting environment variables, and applying a waiting strategy for the container to be ready.

    The build process raises an `ArgumentError` if the specified container image is not compatible with the expected Redis image.

    ## Examples

        # Assuming `ContainerBuilder.build/2` is called from somewhere in the application with a `RedisContainer` configuration:
        iex> config = RedisContainer.new()
        iex> built_container = ContainerBuilder.build(config, [])
        # `built_container` is now a ready-to-use `%Container{}` configured specifically for Redis.

    ## Errors

    - Raises `ArgumentError` if the provided image is not compatible with the default Redis image.
    """
    @spec build(%RedisContainer{}, keyword()) :: %Container{}
    @impl true
    def build(%RedisContainer{} = config, _options) do
      if not String.starts_with?(config.image, RedisContainer.default_image()) do
        raise ArgumentError,
          message:
            "Image #{config.image} is not compatible with #{RedisContainer.default_image()}"
      end

      new(config.image)
      |> with_exposed_port(config.port)
      |> with_waiting_strategy(
        CommandWaitStrategy.new(["redis-cli", "PING"], config.wait_timeout)
      )
    end
  end
end
