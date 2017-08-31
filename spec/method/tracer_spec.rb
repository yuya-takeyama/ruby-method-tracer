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

      expect(tracer).to have_span("test span")
    end

    it "allows to pass tags" do
      tags = {'span.kind' => 'test'}
      Method::Tracer.trace("test span", tags: tags) { true }

      expect(tracer).to have_span.with_tag(tags)
    end

    it "allows to specify custom per-method-call tracer" do
      local_tracer = Test::Tracer.new
      Method::Tracer.trace("test span", tracer: local_tracer) { true }

      expect(tracer).not_to have_spans
      expect(local_tracer).to have_span("test span")
    end

    context "exception is thrown within yielded block" do
      let(:error) { StandardError.new }

      it "re-raise the exception" do
        expect { Method::Tracer.trace("test span") { raise error } }.to raise_error(error)
      end

      it "sets error tag to true" do
        expect { Method::Tracer.trace("test span") { raise error } }.to raise_error do |_|
          expect(tracer).to have_span.with_tag('error', true)
        end
      end

      it "logs error event" do
        expect { Method::Tracer.trace("test span") { raise error } }.to raise_error do |_|
          expect(tracer).to have_span.with_log(event: 'error', :'error.object' => error)
        end
      end
    end

    context "active span provided" do
      let(:span) { tracer.start_span("root") }
      before { Method::Tracer.configure(tracer: tracer, active_span: -> { span }) }

      it "is used as a parent span for newely created span" do
        Method::Tracer.trace("test span") { true }

        expect(tracer).to have_span("test span").with_parent("root")
      end

      it "allows to override active span" do
        new_root = tracer.start_span("new root")
        Method::Tracer.trace("test span", child_of: new_root) { true }

        expect(tracer).to have_span("test span").with_parent("new root")
      end

      it "allows to override active span with proc" do
        new_root = tracer.start_span("new root")
        Method::Tracer.trace("test span", child_of: -> { new_root }) { true }

        expect(tracer).to have_span("test span").with_parent("new root")
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

        expect(tracer).to have_spans(2)
        expect(tracer).to have_span("#<Class:TracedClass>#class_outer_method")
      end

      describe "single method" do
        before { TracedClass.new.inner_method }

        it "creates a new span" do
          expect(tracer).to have_spans(1)
        end

        it "finishes a new span" do
          expect(tracer).to have_spans(1).finished
        end

        it "sets operation_name to Class#method" do
          expect(tracer).to have_span("TracedClass#inner_method")
        end
      end

      describe "chain of methods" do
        before { TracedClass.new.outer_method }

        it "creates a span for each method" do
          expect(tracer).to have_spans(2)
        end

        it "finishes spans for all methods" do
          expect(tracer).to have_spans(2).finished
        end

        it "starts methods starting from outer" do
          expect(tracer).to have_span("TracedClass#inner_method")
            .following_after("TracedClass#outer_method")
            .finished
        end
      end
    end
  end
end
