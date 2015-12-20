# A class that remembers settings for a given window and restrores them by using a given database.
class GtkWindowSettings
  attr_reader :window

  ALLOWED_ARGS = [:db, :name, :window]

  # How the database should be made to look like.
  DB_SCHEMA = {
    tables: {
      "gtk_window_settings" => {
        columns: [
          {name: "id", type: :int, autoincr: true, primarykey: true},
          {name: "name", type: :text},
          {name: "width", type: :int},
          {name: "height", type: :int},
          {name: "pos_x", type: :int},
          {name: "pos_y", type: :int},
          {name: "pos_registered", type: :int}
        ],
        indexes: [
          :name
        ]
      }
    }
  }

  def initialize(args)
    # Check arguments and initialize variables.
    @args = args
    @args.each do |key, _val|
      raise "Invalid argument: '#{key}'." unless ALLOWED_ARGS.include?(key)
    end

    @db = @args[:db]
    @window = @args[:window]
    @name = @args[:name]

    initialize_database

    # Resize and move window to saved size (if saved).
    if @data[:width].to_i > 0 && @data[:height].to_i > 0
      # Use timeout to avoid any other size-code.
      GLib::Timeout.add(25) do
        @window.resize(@data[:width].to_i, @data[:height].to_i)
        false
      end
    end

    @window.move(@data[:pos_x].to_i, @data[:pos_y].to_i) if @data[:pos_registered].to_i == 1

    # Initialize events for the window.
    @window.signal_connect_after(:size_allocate, &method(:on_window_size_request))
    @window.signal_connect(:configure_event, &method(:on_window_moved))
  end

  # Called when the window is resized. Writes the new size to the database.
  def on_window_size_request(*_args)
    GLib::Source.remove(@size_request_timeout) if @size_request_timeout

    @size_request_timeout = GLib::Timeout.add(500, &lambda do
      begin
        @size_request_timeout = nil

        if @window && !@window.destroyed?
          size = @window.size
          @db.update(:gtk_window_settings, {width: size[0], height: size[1]}, id: @id) if size[0].to_i > 0 && size[1].to_i > 0
        end
      ensure
        return false
      end
    end)

    # If false isnt returned the event might be canceled, which can lead to very buggy behaviour.
    false
  end

  # Called when the window is moved on the screen. Writes the new size to the database.
  def on_window_moved(*_args)
    GLib::Source.remove(@moved_timeout) if @moved_timeout

    @moved_timeout = GLib::Timeout.add(500) do
      @moved_timeout = nil

      if @window && !@window.destroyed?
        pos = @window.position
        @db.update(:gtk_window_settings, {pos_x: pos[0], pos_y: pos[1], pos_registered: 1}, id: @id) if pos[0].to_i >= 0 && pos[1].to_i >= 0
      end

      false
    end

    # If false isnt returned the event might be canceled, which can lead to very buggy behaviour.
    false
  end

private

  def initialize_database
    # Check structure of database and load window-settings.
    Baza::Revision.new.init_db(db: @db, schema: DB_SCHEMA)

    if @data = @db.single(:gtk_window_settings, name: @name)
      @id = @data.fetch(:id)
    else
      @id = @db.insert(:gtk_window_Settings, {name: @name}, return_id: true)
      @data = @db.single(:gtk_window_settings, id: @id)
    end
  end
end
