# NOTE: This file is auto generated by OpenAPI Generator 7.0.1 (https://openapi-generator.tech).
# Do not edit this file manually.

defmodule DockerEngineAPI.Model.UnlockKeyResponse do
  @moduledoc """
  
  """

  @derive Jason.Encoder
  defstruct [
    :UnlockKey
  ]

  @type t :: %__MODULE__{
    :UnlockKey => String.t | nil
  }

  def decode(value) do
    value
  end
end

