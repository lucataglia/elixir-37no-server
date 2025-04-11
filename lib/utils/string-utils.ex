defmodule Utils.String do
  def ensure_min_length(str \\ "", min_length, pad_char \\ " ", mode) do
    current_length = String.length(str) || 1

    if current_length < min_length do
      case mode do
        :right ->
          str <> String.duplicate(pad_char, min_length - current_length)

        :left ->
          String.duplicate(pad_char, min_length - current_length) <> str

        _ ->
          str <> String.duplicate(pad_char, min_length - current_length)
      end
    else
      str
    end
  end
end
