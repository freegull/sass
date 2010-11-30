module Sass
  module Tree
    # A static node that is the root node of the Sass document.
    class RootNode < Node
      # The Sass template from which this node was created
      #
      # @param template [String]
      attr_reader :template

      # @param template [String] The Sass template from which this node was created
      def initialize(template)
        super()
        @template = template
      end

      # @see Node#to_s
      def to_s(*args)
        super
      rescue Sass::SyntaxError => e
        e.sass_template ||= @template
        raise e
      end

      # Runs the dynamic Sass code *and* computes the CSS for the tree.
      #
      # @see #perform
      # @see #to_s
      def render
        result, extends = Visitors::Cssize.visit(perform(Environment.new))
        result = result.do_extend(extends) unless extends.empty?
        result.to_s
      end

      # @see Node#perform
      def perform(environment)
        environment.options = @options if environment.options.nil? || environment.options.empty?
        super
      rescue Sass::SyntaxError => e
        e.sass_template ||= @template
        raise e
      end

      # @see \{Node#perform!}
      def perform!(environment)
        environment.options = @options if environment.options.nil? || environment.options.empty?
        super
      end

      # Converts a node to Sass code that will generate it.
      #
      # @param opts [{Symbol => Object}] An options hash (see {Sass::CSS#initialize})
      # @return [String] The Sass code corresponding to the node
      def to_sass(opts = {})
        to_src(opts, :sass)
      end

      # Converts a node to SCSS code that will generate it.
      #
      # @param opts [{Symbol => Object}] An options hash (see {Sass::CSS#initialize})
      # @return [String] The SCSS code corresponding to the node
      def to_scss(opts = {})
        to_src(opts, :scss)
      end

      protected

      # @see Node#to_src
      def to_src(opts, fmt)
        Sass::Util.enum_cons(children + [nil], 2).map do |child, nxt|
          child.send("to_#{fmt}", 0, opts) +
            if nxt &&
                (child.is_a?(CommentNode) && child.line + child.value.count("\n") + 1 == nxt.line) ||
                (child.is_a?(ImportNode) && nxt.is_a?(ImportNode) && child.line + 1 == nxt.line) ||
                (child.is_a?(VariableNode) && nxt.is_a?(VariableNode) && child.line + 1 == nxt.line)
              ""
            else
              "\n"
            end
        end.join.rstrip + "\n"
      end

      # Computes the CSS corresponding to this Sass tree.
      #
      # @param args [Array] ignored
      # @return [String] The resulting CSS
      # @see Sass::Tree
      def _to_s(*args)
        result = String.new
        children.each do |child|
          next if child.invisible?
          child_str = child.to_s(1)
          result << child_str + (style == :compressed ? '' : "\n")
        end
        result.rstrip!
        return "" if result.empty?
        result << "\n"
        unless Sass::Util.ruby1_8? || result.ascii_only?
          if children.first.is_a?(CharsetNode)
            begin
              encoding = children.first.name
              # Default to big-endian encoding, because we have to decide somehow
              encoding << 'BE' if encoding =~ /\Autf-(16|32)\Z/i
              result = result.encode(Encoding.find(encoding))
            rescue EncodingError
            end
          end

          result = "@charset \"#{result.encoding.name}\";#{
            style == :compressed ? '' : "\n"
          }".encode(result.encoding) + result
        end
        result
      end

      # Returns an error message if the given child node is invalid,
      # and false otherwise.
      #
      # Only property nodes are invalid at root level.
      #
      # @see Node#invalid_child?
      def invalid_child?(child)
        case child
        when Tree::ExtendNode
          "Extend directives may only be used within rules."
        when Tree::PropNode
          "Properties aren't allowed at the root of a document." +
            child.pseudo_class_selector_message
        else
          return
        end
      end
    end
  end
end
