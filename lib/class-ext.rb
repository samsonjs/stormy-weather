# Copyright 2012 Sami Samhuri <sami@samhuri.net>

class Class

  def singleton
    (class <<self; self end)
  end

  def define_class_method(name, &body)
    singleton.send(:define_method, name, &body)
  end

end
