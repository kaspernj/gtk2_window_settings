#A class that remembers settings for a given window and restrores them by using a given database.
class Gtk2_window_settings
  #Allowed given arguments.
  ALLOWED_ARGS = [:db, :name, :window]
  
  #How the database should be made to look like.
  DB_SCHEMA = {
    "tables" => {
      "Gtk2_window_settings" => {
        "columns" => [
          {"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
          {"name" => "name", "type" => "text"},
          {"name" => "width", "type" => "int"},
          {"name" => "height", "type" => "int"},
          {"name" => "pos_x", "type" => "int"},
          {"name" => "pos_y", "type" => "int"},
          {"name" => "pos_registered", "type" => "int"}
        ],
        "indexes" => [
          "name"
        ]
      }
    }
  }
  
  #The window that this objects controls.
  attr_reader :window
  
  def initialize(args)
    #Check arguments and initialize variables.
    @args = args
    @args.each do |key, val|
      raise "Invalid argument: '#{key}'." if !ALLOWED_ARGS.include?(key)
    end
    
    @db = @args[:db]
    @window = @args[:window]
    @name = @args[:name]
    
    #Check structure of database and load window-settings.
    Knj::Db::Revision.new.init_db("db" => @db, "schema" => DB_SCHEMA)
    
    if @data = @db.single(:Gtk2_window_settings, :name => @name)
      @id = @data[:id]
    else
      @id = @db.insert(:Gtk2_window_Settings, {:name => @name}, :return_id => true)
      @data = @db.single(:Gtk2_window_settings, :id => @id)
    end
    
    #Resize and move window to saved size (if saved).
    if @data[:width].to_i > 0 and @data[:height].to_i > 0
      #Use timeout to avoid any other size-code.
      Gtk.timeout_add(25) do
        @window.resize(@data[:width].to_i, @data[:height].to_i)
        false
      end
    end
    
    @window.move(@data[:pos_x].to_i, @data[:pos_y].to_i) if @data[:pos_registered].to_i == 1
    
    #Initialize events for the window.
    @window.signal_connect_after(:size_request, &self.method(:on_window_size_request))
    @window.signal_connect(:configure_event, &self.method(:on_window_moved))
  end
  
  #Called when the window is resized. Writes the new size to the database.
  def on_window_size_request(*args)
    Gtk.timeout_remove(@size_request_timeout) if @size_request_timeout
    
    @size_request_timeout = Gtk.timeout_add(500) do
      @size_request_timeout = nil
      
      if @window and !@window.destroyed?
        size = @window.size
        @db.update(:Gtk2_window_settings, {:width => size[0], :height => size[1]}, {:id => @id}) if size[0].to_i > 0 and size[1].to_i > 0
      end
      
      false
    end
    
    #If false isnt returned the event might be canceled, which can lead to very buggy behaviour.
    return false
  end
  
  #Called when the window is moved on the screen. Writes the new size to the database.
  def on_window_moved(*args)
    Gtk.timeout_remove(@moved_timeout) if @moved_timeout
    
    @moved_timeout = Gtk.timeout_add(500) do
      @moved_timeout = nil
      
      if @window and !@window.destroyed?
        pos = @window.position
        @db.update(:Gtk2_window_settings, {:pos_x => pos[0], :pos_y => pos[1], :pos_registered => 1}, {:id => @id}) if pos[0].to_i >= 0 and pos[1].to_i >= 0
      end
      
      false
    end
    
    #If false isnt returned the event might be canceled, which can lead to very buggy behaviour.
    return false
  end
end