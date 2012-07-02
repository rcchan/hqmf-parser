require_relative '../../../test_helper'

class HQMFGeneratorTest < Test::Unit::TestCase
  def setup
    # Parse the sample file and convert to the model
    hqmf_xml = File.open("test/fixtures/2.0/NQF59New.xml").read
    doc = HQMF2::Document.new(hqmf_xml)
    model = doc.to_model
    # serialize the model using the generator back to XML and then
    # reparse it
    @hqmf_xml = HQMF2::Generator::ModelProcessor.to_hqmf(model)
    doc = HQMF2::Document.new(@hqmf_xml)
    @model = doc.to_model
  end

  def test_roundtrip
    assert_equal 'foo', @model.id
    assert_equal "Sample Quality Measure Document", @model.title.strip
    assert_equal "This is the measure description.", @model.description.strip
    data_criteria = @model.all_data_criteria
    assert_equal 33, data_criteria.length

    criteria = @model.data_criteria('DiabetesMedNotAdministeredForNoStatedReason')
    assert criteria.negation
    assert !criteria.negation_code_list_id

    criteria = @model.data_criteria('DiabetesMedNotAdministeredPatientAllergic')
    assert criteria.negation
    assert_equal '1.2.3.4', criteria.negation_code_list_id

    criteria = @model.data_criteria('birthdateFiftyYearsBeforeMeasurementPeriod')
    assert_equal :characteristic, criteria.type
    assert_equal 'birthdateFiftyYearsBeforeMeasurementPeriod', criteria.title
    assert_equal :birthtime, criteria.property
    assert_equal 1, criteria.temporal_references.length
    assert_equal 'SBS', criteria.temporal_references[0].type
    assert_equal 'MeasurePeriod', criteria.temporal_references[0].reference.id
    assert criteria.temporal_references[0].range.low
    assert_equal '50', criteria.temporal_references[0].range.low.value
    assert_equal 'a', criteria.temporal_references[0].range.low.unit
    assert !criteria.temporal_references[0].range.high

    criteria = @model.data_criteria('DummyProcedureAfterHasDiabetesWithCount')
    assert_equal :procedures, criteria.type
    assert_equal 'completed', criteria.status
    assert_equal '20100101', criteria.effective_time.low.value
    assert_equal '20111231', criteria.effective_time.high.value
    assert criteria.effective_time.low.inclusive
    assert criteria.effective_time.high.inclusive
    assert_equal 1, criteria.temporal_references.length
    assert_equal '-1', criteria.temporal_references[0].range.low.value
    assert_equal 'a', criteria.temporal_references[0].range.low.unit
    assert_equal 'HasDiabetes', criteria.temporal_references[0].reference.id
    assert !criteria.code_list_id
    assert criteria.inline_code_list
    assert criteria.inline_code_list['SNOMED-CT']
    assert_equal '127355002', criteria.inline_code_list['SNOMED-CT'][0]
    assert_equal 1, criteria.subset_operators.size
    assert_equal 'SUMMARY', criteria.subset_operators[0].type
    assert_equal '2', criteria.subset_operators[0].value.low.value

    criteria = @model.data_criteria('EDorInpatientEncounter')
    assert_equal :encounters, criteria.type
    assert !criteria.inline_code_list
    assert_equal '2.16.840.1.113883.3.464.1.42', criteria.code_list_id
    assert criteria.effective_time.high
    assert criteria.effective_time.high.derived?
    assert_equal 'EndDate.add(new PQ(-2,"a"))', criteria.effective_time.high.expression

    criteria = @model.data_criteria('anyDiabetes')
    assert_equal :derived, criteria.type
    assert_equal 'UNION', criteria.derivation_operator
    assert_equal 2, criteria.children_criteria.size
    assert_equal 'HasDiabetes', criteria.children_criteria[0]
    assert_equal 'HasGestationalDiabetes', criteria.children_criteria[1]

    criteria = @model.data_criteria('HasPolycysticOvaries')
    assert_equal :conditions, criteria.type
    assert_equal '2.16.840.1.113883.3.464.1.98', criteria.code_list_id
    assert criteria.effective_time.high
    assert criteria.effective_time.high.derived?
    assert_equal 'EndDate', criteria.effective_time.high.expression

    criteria = @model.data_criteria('HbA1C')
    assert_equal :results, criteria.type
    assert_equal 'HbA1C', criteria.title
    assert_equal 1, criteria.subset_operators.length
    assert_equal 'RECENT', criteria.subset_operators[0].type
    assert_equal '2.16.840.1.113883.3.464.1.72', criteria.code_list_id
    assert_equal 'completed', criteria.status
    assert_equal nil, criteria.effective_time
    assert_equal HQMF::Range, criteria.value.class
    assert_equal nil, criteria.value.high
    assert criteria.value.low
    assert_equal '9', criteria.value.low.value
    assert_equal '%', criteria.value.low.unit

    criteria = @model.data_criteria('DiabetesMedAdministered')
    assert !criteria.negation
    assert_equal :medications, criteria.type
    assert_equal 'DiabetesMedAdministered', criteria.title
    assert_equal '2.16.840.1.113883.3.464.1.94', criteria.code_list_id
    assert criteria.effective_time
    assert_equal nil, criteria.effective_time.high
    assert criteria.effective_time.low
    assert_equal true, criteria.effective_time.low.derived?
    assert_equal 'StartDate.add(new PQ(-2,"a"))', criteria.effective_time.low.expression

    criteria = @model.data_criteria('DiabetesMedSupplied')
    assert_equal :medication_supply, criteria.type
    assert_equal 'DiabetesMedSupplied', criteria.title
    assert_equal '2.16.840.1.113883.3.464.1.94', criteria.code_list_id
    assert criteria.effective_time
    assert_equal nil, criteria.effective_time.low
    assert criteria.effective_time.high
    assert_equal true, criteria.effective_time.high.derived?
    assert_equal 'EndDate.add(new PQ(-2,"a"))', criteria.effective_time.high.expression
      
    all_population_criteria = @model.all_population_criteria
    assert_equal 4, all_population_criteria.length
  
    codes = all_population_criteria.collect {|p| p.id}
    %w(IPP DENOM NUMER DENEXCEP).each do |c|
      assert codes.include?(c)
    end

    ipp = @model.population_criteria('IPP')
    assert ipp.conjunction?
    assert_equal 'allTrue', ipp.conjunction_code
    assert_equal 1, ipp.preconditions.length
    assert_equal false, ipp.preconditions[0].conjunction?
    assert_equal 'ageBetween17and64', ipp.preconditions[0].reference.id

    den = @model.population_criteria('DENOM')
    assert_equal 1, den.preconditions.length
    assert den.preconditions[0].conjunction?
    assert_equal 'atLeastOneTrue', den.preconditions[0].conjunction_code
    assert_equal 5, den.preconditions[0].preconditions.length
    assert den.preconditions[0].preconditions[0].conjunction?
    assert_equal 'allTrue', den.preconditions[0].preconditions[0].conjunction_code
    assert_equal 2, den.preconditions[0].preconditions[0].preconditions.length
    assert_equal false, den.preconditions[0].preconditions[0].preconditions[0].conjunction?
    assert_equal 'HasDiabetes', den.preconditions[0].preconditions[0].preconditions[0].reference.id
  
    num = @model.population_criteria('NUMER')
    assert_equal 1, num.preconditions.length
    assert_equal false, num.preconditions[0].conjunction?
    assert_equal 'HbA1C', num.preconditions[0].reference.id

    ipp = @model.population_criteria('DENEXCEP')
    assert ipp.conjunction?
    assert_equal 'atLeastOneTrue', ipp.conjunction_code
    assert_equal 3, ipp.preconditions.length
  end
  
  def test_schema_valid
    doc = Nokogiri.XML(@hqmf_xml)
    xsd_file = File.open("test/fixtures/2.0/schema/EMeasureNew.xsd")
    xsd = Nokogiri::XML.Schema(xsd_file)
    error_count = 0
    xsd.validate(doc).each do |error|
      puts error.message
      error_count = error_count + 1
    end
    assert_equal 0, error_count
  end
end
