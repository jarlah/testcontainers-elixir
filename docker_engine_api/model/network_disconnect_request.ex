# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.NetworkDisconnectRequest do
  @moduledoc """
  
  """

  @derive Jason.Encoder
  defstruct [
    :Container,
    :Force
  ]

  @type t :: %__MODULE__{
    :Container => String.t | nil,
    :Force => boolean() | nil
  }

  def decode(value) do
    value
  end
end

