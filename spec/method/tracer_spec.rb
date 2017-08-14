require "spec_helper"

RSpec.describe Method::Tracer do
  let(:tracer) { Test::Tracer.new }

  describe :trace do
    before { Method::Tracer.configure(tracer: tracer) }

    it "returns result from the yielded block" do
      expect(Method::Tracer.trace("test span") { true }).to eq(true)
    end

    it "creates a new span" do
      Method::Tracer.trace("test span") { true }

      expect(tracer.finished_spans.last.operation_name).to eq("test span")
    end

    it "allows to pass tags" do
      tags = {'span.kind' => 'test'}
      Method::Tracer.trace("test span", tags: tags) { true }

      expect(tracer.finished_spans.last.tags).to eq(tags)
    end

    context "exception is thrown within yielded block" do
      let(:error) { StandardError.new }

      it "re-raise the exception" do
        expect { Method::Tracer.trace("test span") { raise error } }.to raise_error(error)
      end

      it "sets error tag to true" do
        expect { Method::Tracer.trace("test span") { raise error } }.to raise_error do |_|
          expect(tracer.finished_spans.last.tags['error']).to eq(true)
        end
      end

      it "logs error event" do
        expect { Method::Tracer.trace("test span") { raise error } }.to raise_error do |_|
          log = tracer.finished_spans.last.logs.first
          expect(log.event).to eq('error')
          expect(log.fields[:'error.object']).to eq(error)
        end
      end
    end

    context "active span provided" do
      let(:span) { tracer.start_span("root") }
      before { Method::Tracer.configure(tracer: tracer, active_span: -> { span }) }

      it "is used as a parent span for newely created span" do
        Method::Tracer.trace("test span") { true }

        expect(tracer.finished_spans.last.context.parent_span_id).to eq(span.context.span_id)
      end

      it "allows to override active span" do
        new_root = tracer.start_span("new root")
        Method::Tracer.trace("test span", child_of: new_root) { true }

        expect(tracer.finished_spans.last.context.parent_span_id).to eq(new_root.context.span_id)
      end
    end
  end

  describe "ClassMethods" do
    class TracedClass
      include Method::Tracer

      class << self
        include Method::Tracer

        def class_outer_method
          class_inner_method
        end

        def class_inner_method
        end

        trace_method :class_outer_method, :class_inner_method
      end

      def outer_method
        inner_method
      end

      def inner_method
      end

      trace_method :outer_method, :inner_method
    end

    before { Method::Tracer.configure(tracer: tracer) }

    describe :trace_method do
      it "works with class methods" do
        TracedClass.class_outer_method

        expect(tracer.spans.size).to eq(2)
        expect(tracer.spans.first.operation_name).to eq("#<Class:TracedClass>#class_outer_method")
      end

      describe "single method" do
        before { TracedClass.new.inner_method }

        it "creates a new span" do
          expect(tracer.spans.size).to eq(1)
        end

        it "finishes a new span" do
          expect(tracer.finished_spans.size).to eq(1)
        end

        it "sets operation_name to Class#method" do
          expect(tracer.finished_spans.first.operation_name).to eq("TracedClass#inner_method")
        end
      end

      describe "chain of methods" do
        before { TracedClass.new.outer_method }

        it "creates a span for each method" do
          expect(tracer.spans.size).to eq(2)
        end

        it "finishes spans for all methods" do
          expect(tracer.finished_spans.size).to eq(2)
        end

        it "starts methods starting from outer" do
          expect(tracer.spans.first.operation_name).to eq("TracedClass#outer_method")
          expect(tracer.spans.last.operation_name).to eq("TracedClass#inner_method")
        end

        it "finishes methods starting from inner" do
          expect(tracer.finished_spans.first.operation_name).to eq("TracedClass#inner_method")
          expect(tracer.finished_spans.last.operation_name).to eq("TracedClass#outer_method")
        end
      end
    end
  end
end
