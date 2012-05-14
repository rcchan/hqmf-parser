module HQMF
  # Represents a data criteria specification
  class DataCriteria

    include HQMF::Conversion::Utilities

    attr_reader :title,:description,:section,:subset_code,:code_list_id, :inline_code_list, :standard_category, :qds_data_type, :negation
    attr_accessor :id, :value, :effective_time, :status, :temporal_references, :property, :type
  
    # Create a new data criteria instance
    # @param [String] id
    # @param [String] title
    # @param [String] description
    # @param [String] standard_category
    # @param [String] qds_data_type
    # @param [String] subset_code
    # @param [String] code_list_id
    # @param [String] property
    # @param [String] type
    # @param [String] status
    # @param [Value|Range|Coded] value
    # @param [Range] effective_time
    # @param [Hash<String,String>] inline_code_list
    # @param [boolean] negation
    # @param [Array<TemporalReference>] temporal_references
    def initialize(id, title, description, standard_category, qds_data_type, subset_code, 
        code_list_id, property,type, status, value, effective_time, inline_code_list,
        negation,temporal_references)
      @id = id
      @title = title
      @description = description
      @standard_category = standard_category
      @qds_data_type = qds_data_type
      @subset_code = subset_code
      @code_list_id = code_list_id
      @property = property
      @type = type
      @status = status
      @value = value
      @effective_time = effective_time
      @inline_code_list = inline_code_list
      @negation = negation
      @temporal_references = temporal_references
    end
    
    # Create a new data criteria instance from a JSON hash keyed with symbols
    def self.from_json(id, json)
      title = json["title"] if json["title"]
      description = json["description"] if json["description"]
      standard_category = json["standard_category"] if json["standard_category"]
      qds_data_type = json["qds_data_type"] if json["standard_category"]
      subset_code = json["subset_code"] if json["subset_code"]
      code_list_id = json["code_list_id"] if json["code_list_id"]
      property = json["property"].to_sym if json["property"]
      type = json["type"].to_sym if json["type"]
      status = json["status"] if json["status"]
      negation = json["negation"] || false
      
      temporal_references = json["temporal_references"].map do |temporal_reference|
        HQMF::TemporalReference.from_json(temporal_reference)
      end if (json['temporal_references'])

      value = convert_value(json["value"]) if json["value"]
      effective_time = HQMF::Range.from_json(json["effective_time"]) if json["effective_time"]
      inline_code_list = json["inline_code_list"].inject({}){|memo,(k,v)| memo[k.to_s] = v; memo} if json["inline_code_list"]
      
      HQMF::DataCriteria.new(id, title, description, standard_category, qds_data_type, subset_code, code_list_id,
                            property, type, status, value, effective_time, inline_code_list, negation, temporal_references)
    end
    
    def to_json
      json = base_json
      {self.id.to_s.to_sym => json}
    end
    
    def clone
      HQMF::DataCriteria.from_json(id, JSON.parse(base_json.to_json))
    end
    
    private 
    
    def base_json
      json = build_hash(self, [:title,:description,:standard_category,:qds_data_type,:subset_code,:code_list_id, :property, :type, :status, :negation])
      json[:value] = self.value.to_json if self.value
      json[:effective_time] = self.effective_time.to_json if self.effective_time
      json[:inline_code_list] = self.inline_code_list if self.inline_code_list
      temporal_references = json_array(@temporal_references) if @temporal_references && !@temporal_references.empty?
      json[:temporal_references] = temporal_references if temporal_references
      json
    end
    
    def self.convert_value(json)
      value = nil
      type = json["type"]
      case type
        when 'TS'
          value = HQMF::Value.from_json(json)
        when 'IVL_PQ'
          value = HQMF::Range.from_json(json)
        when 'CD'
          value = HQMF::Coded.from_json(json)
        else
          raise "Unknown value type [#{type}]"
        end
      value
    end
    

  end
  
end