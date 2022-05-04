module Generator::Helpers
  KEYWORDS = {"abstract", "alias", "begin", "def", "end", "enum", "in", "module", "next", "out", "self", "select", "extend", "initialize"}

  def to_get_type_function(struct_info : StructInfo)
    "#{struct_info.namespace.name.underscore}_#{struct_info.name.underscore}_get_type"
  end

  def to_lib_namespace(namespace : Namespace)
    name = namespace.name
    "Lib#{name[0].upcase}#{name[1..-1]}"
  end

  def to_identifier(name : String) : String
    name = name.tr("-", "_") if name.index("-")
    KEYWORDS.includes?(name) ? "_#{name}" : name
  end

  def to_type_name(name : String) : String
    name = name.tr("-", "_") if name.index("-")
    name = name.camelcase
    if name.starts_with?(/[_0-9]/)
      "G#{name}"
    elsif name[0].lowercase?
      "#{name[0].upcase}#{name[1..-1]}"
    else
      name
    end
  end

  def to_method_name(name : String) : String
    name.tr("-", "_")
  end

  def abstract_interface_name(iface : InterfaceInfo)
    # I hope for the best that this wont cause any name clash.... but if so, at least it can be fixed
    # in a single place once someone report such clash in some library.
    "Abstract#{to_type_name(iface.name)}"
  end

  def type_info_default_value(type_info : TypeInfo)
    case type_info.tag
    when .boolean?, .int32? then "0"
    when .u_int32?          then "0_u32"
    when .int16?            then "0_i16"
    when .u_int16?          then "0_u16"
    when .int64?            then "0_i64"
    when .u_int64?          then "0_u64"
    else
      Log.warn { "Don't know what would be a default value for type #{type_info.tag}." }
      "0" # just to make compiler happy
    end
  end

  def to_lib_type(tag : TypeTag) : String
    case tag
    when .void?             then "Void"
    when .boolean?          then "LibC::Int"
    when .int8?             then "Int8"
    when .u_int8?           then "UInt8"
    when .int16?            then "Int16"
    when .u_int16?          then "UInt16"
    when .int32?            then "Int32"
    when .u_int32?          then "UInt32"
    when .int64?            then "Int64"
    when .u_int64?          then "UInt64"
    when .float?            then "Float32"
    when .double?           then "Float64"
    when .utf8?, .filename? then "LibC::Char"
    when .gtype?            then "UInt64"
    when .g_list?           then "LibGLib::List"
    when .gs_list?          then "LibGLib::SList"
    when .g_hash?           then "Void"
    when .unichar?          then "UInt32"
    when .error?            then "Void"
    else
      raise Error.new("Unknown lib representation for #{tag}")
    end
  end

  def to_lib_type(type : TypeInfo, structs_as_void : Bool = false, include_namespace : Bool = true, is_arg : Bool = false) : String
    tag = type.tag

    is_pointer = type.pointer?
    value = if tag.interface?
              iface = type.interface
              # Consider all interfaces a Void* makes a lot of things easier to the generator that doesn't need to write
              # zillion of pointer casts
              return "Pointer(Void)" if iface.nil?

              case iface
              when CallbackInfo
                "Void*"
              when EnumInfo
                to_lib_type(iface.storage_type)
              when UnionInfo
                to_lib_type(iface, include_namespace)
              when ObjectInfo, StructInfo, InterfaceInfo
                if structs_as_void
                  "Void"
                else
                  name = to_type_name(iface.name)
                  include_namespace ? "#{to_lib_namespace(iface.namespace)}::#{name}" : name
                end
              else
                raise Error.new("Unknown lib representation for #{iface.class.name}.")
              end
            elsif tag.array?
              array_type_name = to_lib_type(type.param_type, include_namespace)
              if is_arg
                array_type_name
              else
                array_len = type.array_fixed_size
                array_len > 0 ? "#{array_type_name}[#{array_len}]" : array_type_name
              end
            else
              to_lib_type(tag)
            end
    is_pointer ? "Pointer(#{value})" : value
  end

  def to_lib_type(info : BaseInfo, include_namespace : Bool = true) : String
    return to_lib_type(info, include_namespace) if info.as?(TypeInfo)

    case info
    when FunctionInfo
      name = info.symbol
      include_namespace ? "#{to_lib_namespace(info.namespace)}.#{name}" : name
    else
      name = to_type_name(info.name)
      include_namespace ? "#{to_lib_namespace(info.namespace)}::#{name}" : name
    end
  end

  def convert_to_lib(var : String, type : TypeInfo, _transfer : Transfer) : String
    tag = type.tag
    case tag
    when .interface?, .utf8?, .filename?
      "#{var}.to_unsafe"
    else
      var
    end
  end

  def to_crystal_arg_decl(name : String)
    if KEYWORDS.includes?(name)
      "#{name} _#{name}"
    else
      to_identifier(name)
    end
  end

  def callable_to_crystal_proc(info : CallableInfo) : String
    String.build do |s|
      s << "Proc("
      callable_to_crystal_types(s, info)
      s << ')'
    end
  end

  def callable_to_crystal_types(io : IO, info : CallableInfo) : Nil
    # He must hide the user_data arg from CallbackInfo
    stop_at = info.is_a?(CallbackInfo) ? info.args.size - 1 : -1
    info.args.each_with_index do |arg, i|
      break if i == stop_at

      arg_type_info = arg.type_info
      nullmark = '?' if arg.nullable?
      io << to_crystal_type(arg_type_info, include_namespace: true) << nullmark << ','
    end
    io << to_crystal_type(info.return_type, include_namespace: true)
  end

  def to_crystal_type(tag : TypeTag) : String
    case tag
    when .void?             then "Nil"
    when .boolean?          then "Bool"
    when .int8?             then "Int8"
    when .u_int8?           then "UInt8"
    when .int16?            then "Int16"
    when .u_int16?          then "UInt16"
    when .int32?            then "Int32"
    when .u_int32?          then "UInt32"
    when .int64?            then "Int64"
    when .u_int64?          then "UInt64"
    when .float?            then "Float32"
    when .double?           then "Float64"
    when .utf8?, .filename? then "::String"
    when .gtype?            then "UInt64"
    when .g_list?           then "GLib::List"
    when .gs_list?          then "GLib::SList"
    when .g_hash?           then "Void"
    when .unichar?          then "UInt32"
    when .error?            then "GLib::Error"
    else
      raise Error.new("Unknown Crystal representation for #{tag}")
    end
  end

  # @is_arg: The type is means to be used in a argument list for some method
  def to_crystal_type(type : TypeInfo, include_namespace : Bool = true, is_arg : Bool = false) : String
    return "_" if is_arg && BindingConfig.handmade?(type)

    tag = type.tag
    case tag
    when .interface?
      iface = type.interface
      return "Pointer(Void)" if iface.nil?
      to_crystal_type(iface, include_namespace)
    when .array?
      t = to_crystal_type(type.param_type, include_namespace, is_arg: is_arg)
      "Enumerable(#{t})"
    when tag.utf8?, .filename?, .g_list?, .gs_list?, .error?
      to_crystal_type(tag)
    else
      tag_str = to_crystal_type(tag)
      if type.pointer? && tag.void?
        "Pointer(Void)"
      elsif type.pointer? && !tag.utf8? && !tag.g_list? && !tag.gs_list?
        "Pointer(#{tag_str})"
      else
        tag_str
      end
    end
  end

  def to_crystal_type(info : BaseInfo, include_namespace : Bool = true) : String
    case info
    when TypeInfo
      to_crystal_type(info, include_namespace)
    when SignalInfo
      name = to_type_name(info.name)
      name = "#{to_type_name(info.namespace.name)}::#{name}" if include_namespace
      "#{name}Signal"
    else
      name = to_type_name(info.name)
      name = "#{to_type_name(info.namespace.name)}::#{name}" if include_namespace
      name
    end
  end

  # @var: Variable name in lib format.
  # @type: Type info
  # @transfer: Transfer mode
  def convert_to_crystal(var : String, type : TypeInfo, args : Indexable?, transfer : Transfer) : String
    tag = type.tag
    case tag
    when .boolean?
      "GICrystal.to_bool(#{var})"
    when .int8?, .u_int8?, .int16?, .u_int16?, .int32?, .u_int32?, .int64?, .u_int64?, .float?, .double?, .unichar?, .gtype?
      var
    when .utf8?, .filename?
      expr = if transfer.full?
               "GICrystal.transfer_full(#{var})"
             else
               "::String.new(#{var})"
             end
      tag.filename? ? "::Path.new(#{expr})" : expr
    when .interface?
      iface = type.interface.not_nil!
      convert_to_crystal(var, iface, args, transfer)
    when .error?
      "GLib::Error.new(#{var}, GICrystal::Transfer::#{transfer})"
    when .void?
      type.pointer? ? var : ""
    when .g_list?
      param_type = to_crystal_type(type.param_type)
      "#{to_crystal_type(tag)}(#{param_type}).new(#{var}, GICrystal::Transfer::#{transfer})"
    when .gs_list?
      param_type = to_crystal_type(type.param_type)
      "#{to_crystal_type(tag)}(#{param_type}).new(#{var}, GICrystal::Transfer::#{transfer})"
    when .array?
      if type.array_zero_terminated?
        "GICrystal.transfer_null_ended_array(#{var}, GICrystal::Transfer::#{transfer})"
      elsif type.array_fixed_size >= 0
        Log.warn { "Unknown conversion to crystal for fixed size array." }
        var
      elsif type.array_length >= 0
        raise ArgumentError.new("Full args missing to convert array to Crystal") if args.nil?

        "GICrystal.transfer_array(#{var}, #{args[type.array_length].name},GICrystal::Transfer::#{transfer})"
      else
        var
      end
    else
      Log.warn { "Unknown conversion to crystal for #{tag}" }
      var
    end
  end

  def convert_to_crystal(var : String, info : BaseInfo, args : Indexable?, transfer : Transfer) : String
    case info
    when TypeInfo
      convert_to_crystal(var, info, args, transfer)
    when EnumInfo
      "#{to_crystal_type(info, true)}.new(#{var})"
    when ArgInfo
      if info.nullable?
        "(#{var}.null? ? nil : #{convert_to_crystal(var, info.type_info, args, transfer)})"
      else
        convert_to_crystal(var, info.type_info, args, transfer)
      end
    else
      crystal_type = to_crystal_type(info, true)
      crystal_type = abstract_interface_name(info) if info.is_a?(InterfaceInfo)
      "#{crystal_type}.new(#{var}, GICrystal::Transfer::#{transfer})"
    end
  end
end
