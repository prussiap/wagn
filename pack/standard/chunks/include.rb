# -*- encoding : utf-8 -*-

module Card::Chunk
  class Include < Reference
    cattr_reader :options
    @@options = [ :include_name, :view, :item, :items, :type, :size, :title, :hide, :show, :include, :structure ].to_set
    attr_reader :options
      
    Card::Chunk.register_class self, {
      :prefix_re => '\\{\\{',
      :full_re   =>  /^\{\{([^\}]*)\}\}/,
      :idx_char  => '{'    
    }
    
    def interpret match, content
      in_brackets = match[1]
#      warn "in_brackets = #{in_brackets}"
      name, @opt_lists = in_brackets.split '|', 2
      result = case name
        when /^\#\#/ ; '' # invisible comment
        when /^\#/   ;  "<!-- #{CGI.escapeHTML in_brackets} -->"
        when ''      ; '' # no name
        else
          options_at_depth = @options = {}
          opt_list_array = @opt_lists.to_s.split '|'
          opt_list_array.each_with_index do |opt_list, index|            
            process_opt_list opt_list, options_at_depth
            options_at_depth.merge! :include_name => name, :include => in_brackets #yuck, need better name (this is raw stuff)
            if index + 1 < opt_list_array.size
              warn "#{index + 1} < #{@opt_lists.size}"
              options_at_depth = options_at_depth[:items] = {}
            end
          end
          @name = name
        end
      
      @process_chunk = result if !@name
    end
    
    def process_opt_list list_string, hash
      style_hash = {} 
      Hash.new_from_semicolon_attr_list( list_string ).each do |key, value|
        key = key.to_sym
        if @@options.include? key
          hash[key] = value
        else
          style_hash[key] = value
        end
      end
      
      if !style_hash.empty?
        hash[:style] = style_hash.map { |key, value| CGI.escapeHTML "#{style_name}:#{style};" } * ''
      end
    end

    def inspect
      "<##{self.class}:n[#{@name}] p[#{@process_chunk}] txt:#{@text}>"
    end

    def process_chunk
      return @process_chunk if @process_chunk

      referee_name
      if view = @options[:view]
        view = view.to_sym
      end

      @processed = yield @options # this is not necessarily text, sometimes objects for json
    end

    def replace_reference old_name, new_name
      replace_name_reference old_name, new_name
      @text = "{{#{ [ @name.to_s, @opt_lists ].compact * '|' }}}"
    end

  end
end
