# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.TaskSpecResources do
  @moduledoc """
  Resource requirements which apply to each individual container created as part of the service. 
  """

  @derive Jason.Encoder
  defstruct [
    :Limits,
    :Reservations
  ]

  @type t :: %__MODULE__{
    :Limits => DockerEngineAPI.Model.Limit.t | nil,
    :Reservations => DockerEngineAPI.Model.ResourceObject.t | nil
  }

  alias DockerEngineAPI.Deserializer

  def decode(value) do
    value
     |> Deserializer.deserialize(:Limits, :struct, DockerEngineAPI.Model.Limit)
     |> Deserializer.deserialize(:Reservations, :struct, DockerEngineAPI.Model.ResourceObject)
  end
end

