# Copyright 2012 Sami Samhuri <sami@samhuri.net>

class Hash

  def slice(*keys)
    keys.inject({}) do |h, k|
      h[k] = self[k] if has_key?(k)
      h
    end
  end

end
