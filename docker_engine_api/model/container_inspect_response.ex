# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.ContainerInspectResponse do
  @moduledoc """
  
  """

  @derive Jason.Encoder
  defstruct [
    :Id,
    :Created,
    :Path,
    :Args,
    :State,
    :Image,
    :ResolvConfPath,
    :HostnamePath,
    :HostsPath,
    :LogPath,
    :Name,
    :RestartCount,
    :Driver,
    :Platform,
    :MountLabel,
    :ProcessLabel,
    :AppArmorProfile,
    :ExecIDs,
    :HostConfig,
    :GraphDriver,
    :SizeRw,
    :SizeRootFs,
    :Mounts,
    :Config,
    :NetworkSettings
  ]

  @type t :: %__MODULE__{
    :Id => String.t | nil,
    :Created => String.t | nil,
    :Path => String.t | nil,
    :Args => [String.t] | nil,
    :State => DockerEngineAPI.Model.ContainerState.t | nil,
    :Image => String.t | nil,
    :ResolvConfPath => String.t | nil,
    :HostnamePath => String.t | nil,
    :HostsPath => String.t | nil,
    :LogPath => String.t | nil,
    :Name => String.t | nil,
    :RestartCount => integer() | nil,
    :Driver => String.t | nil,
    :Platform => String.t | nil,
    :MountLabel => String.t | nil,
    :ProcessLabel => String.t | nil,
    :AppArmorProfile => String.t | nil,
    :ExecIDs => [String.t] | nil,
    :HostConfig => DockerEngineAPI.Model.HostConfig.t | nil,
    :GraphDriver => DockerEngineAPI.Model.GraphDriverData.t | nil,
    :SizeRw => integer() | nil,
    :SizeRootFs => integer() | nil,
    :Mounts => [DockerEngineAPI.Model.MountPoint.t] | nil,
    :Config => DockerEngineAPI.Model.ContainerConfig.t | nil,
    :NetworkSettings => DockerEngineAPI.Model.NetworkSettings.t | nil
  }

  alias DockerEngineAPI.Deserializer

  def decode(value) do
    value
     |> Deserializer.deserialize(:State, :struct, DockerEngineAPI.Model.ContainerState)
     |> Deserializer.deserialize(:HostConfig, :struct, DockerEngineAPI.Model.HostConfig)
     |> Deserializer.deserialize(:GraphDriver, :struct, DockerEngineAPI.Model.GraphDriverData)
     |> Deserializer.deserialize(:Mounts, :list, DockerEngineAPI.Model.MountPoint)
     |> Deserializer.deserialize(:Config, :struct, DockerEngineAPI.Model.ContainerConfig)
     |> Deserializer.deserialize(:NetworkSettings, :struct, DockerEngineAPI.Model.NetworkSettings)
  end
end
