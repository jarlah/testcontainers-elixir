# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.ContainerWaitResponse do
  @moduledoc """
  OK response to ContainerWait operation
  """

  @derive Jason.Encoder
  defstruct [
    :StatusCode,
    :Error
  ]

  @type t :: %__MODULE__{
    :StatusCode => integer(),
    :Error => DockerEngineAPI.Model.ContainerWaitExitError.t | nil
  }

  alias DockerEngineAPI.Deserializer

  def decode(value) do
    value
     |> Deserializer.deserialize(:Error, :struct, DockerEngineAPI.Model.ContainerWaitExitError)
  end
end
