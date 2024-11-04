# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.SystemDataUsageResponse do
  @moduledoc """
  
  """

  @derive Jason.Encoder
  defstruct [
    :LayersSize,
    :Images,
    :Containers,
    :Volumes,
    :BuildCache
  ]

  @type t :: %__MODULE__{
    :LayersSize => integer() | nil,
    :Images => [DockerEngineAPI.Model.ImageSummary.t] | nil,
    :Containers => [DockerEngineAPI.Model.ContainerSummary.t] | nil,
    :Volumes => [DockerEngineAPI.Model.Volume.t] | nil,
    :BuildCache => [DockerEngineAPI.Model.BuildCache.t] | nil
  }

  alias DockerEngineAPI.Deserializer

  def decode(value) do
    value
     |> Deserializer.deserialize(:Images, :list, DockerEngineAPI.Model.ImageSummary)
     |> Deserializer.deserialize(:Containers, :list, DockerEngineAPI.Model.ContainerSummary)
     |> Deserializer.deserialize(:Volumes, :list, DockerEngineAPI.Model.Volume)
     |> Deserializer.deserialize(:BuildCache, :list, DockerEngineAPI.Model.BuildCache)
  end
end

