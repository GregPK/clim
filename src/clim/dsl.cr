require "./command"

class Clim
  {% if flag?(:spec) %}
    alias ReturnTypeOfRunBlock = NamedTuple(opts: Options::Values, args: Array(String))
    alias RunProc = Proc(Options::Values, Array(String), ReturnTypeOfRunBlock)
  {% else %}
    alias RunProc = Proc(Options::Values, Array(String), Nil)
  {% end %}

  @@main : Command = Command.new("main_command")
  @@defining : Command = @@main
  @@scope_stack : Array(Command) = [] of Command

  module Dsl
    def main_command
      raise ClimException.new "Main command is already defined." unless @@scope_stack.empty?
      @@main = Command.new("main_command")
      @@defining = @@main
    end

    def command(name)
      raise ClimException.new "Main command is not defined." if @@scope_stack.empty?
      @@defining = Command.new(name)
    end

    def desc(desc)
      @@defining.desc = desc
    end

    def usage(usage)
      @@defining.usage = usage
    end

    macro difine_opts(method_name, type, base_default, &proc)
      {% for long_arg in ["long,", ""] %}
        def {{method_name.id}}(short, {{long_arg.id}} default : {{type}} = nil, required = false, desc = "Option description.")
          opt = Option({{type}}).new(
                                      short:            short,
                                      long:             {% if long_arg.empty? %} "", {% else %} {{long_arg.id}} {% end %}
                                      default:          default.nil? ? {{base_default}} : default,
                                      required:         required,
                                      desc:             desc,
                                      value:            default.nil? ? {{base_default}} : default,
                                      set_default_flag: {% if type.id == Bool.id %} true {% else %} !default.nil? {% end %}
                                    )
          @@defining.parser.on(opt.short, {% unless long_arg.empty? %} opt.long, {% end %} opt.desc) {{proc.id}}
          @@defining.opts.add(opt)
        end
      {% end %}
    end

    difine_opts(method_name: "string", type: String | Nil, base_default: nil) { |arg| opt.set_string(arg) }
    difine_opts(method_name: "bool", type: Bool | Nil, base_default: nil) { |arg| opt.set_bool(arg) }
    difine_opts(method_name: "array", type: Array(String) | Nil, base_default: nil) { |arg| opt.add_to_array(arg) }

    def run(&block : RunProc)
      @@defining.run_proc = block
      @@scope_stack.last.sub_cmds << @@defining unless @@scope_stack.empty?
    end

    def sub(&block)
      @@scope_stack.push(@@defining)
      yield
      @@scope_stack.pop
    end

    def start_main(argv)
      @@main.parse_and_run(argv)
    end

    def start(argv)
      start_main(argv)
    rescue ex
      puts ex.message
    end
  end
end
