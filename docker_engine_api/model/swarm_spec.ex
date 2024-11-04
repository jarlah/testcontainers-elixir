# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.SwarmSpec do
  @moduledoc """
  User modifiable swarm configuration.
  """

  @derive Jason.Encoder
  defstruct [
    :Name,
    :Labels,
    :Orchestration,
    :Raft,
    :Dispatcher,
    :CAConfig,
    :EncryptionConfig,
    :TaskDefaults
  ]

  @type t :: %__MODULE__{
    :Name => String.t | nil,
    :Labels => %{optional(String.t) => String.t} | nil,
    :Orchestration => DockerEngineAPI.Model.SwarmSpecOrchestration.t | nil,
    :Raft => DockerEngineAPI.Model.SwarmSpecRaft.t | nil,
    :Dispatcher => DockerEngineAPI.Model.SwarmSpecDispatcher.t | nil,
    :CAConfig => DockerEngineAPI.Model.SwarmSpecCaConfig.t | nil,
    :EncryptionConfig => DockerEngineAPI.Model.SwarmSpecEncryptionConfig.t | nil,
    :TaskDefaults => DockerEngineAPI.Model.SwarmSpecTaskDefaults.t | nil
  }

  alias DockerEngineAPI.Deserializer

  def decode(value) do
    value
     |> Deserializer.deserialize(:Orchestration, :struct, DockerEngineAPI.Model.SwarmSpecOrchestration)
     |> Deserializer.deserialize(:Raft, :struct, DockerEngineAPI.Model.SwarmSpecRaft)
     |> Deserializer.deserialize(:Dispatcher, :struct, DockerEngineAPI.Model.SwarmSpecDispatcher)
     |> Deserializer.deserialize(:CAConfig, :struct, DockerEngineAPI.Model.SwarmSpecCaConfig)
     |> Deserializer.deserialize(:EncryptionConfig, :struct, DockerEngineAPI.Model.SwarmSpecEncryptionConfig)
     |> Deserializer.deserialize(:TaskDefaults, :struct, DockerEngineAPI.Model.SwarmSpecTaskDefaults)
  end
end

