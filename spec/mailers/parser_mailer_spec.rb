require 'spec_helper'
require 'message'

describe ParserMailer, type: :mailer do
  describe 'daily_report' do
    before do
      allow_any_instance_of(ActionMailer::Base::NullMail).to receive(:null_mail?).and_return(true)
      allow_any_instance_of(Mail::Message).to receive(:null_mail?).and_return(false)
    end
    let(:user) { FactoryGirl.create :developer }
    let(:parser) { FactoryGirl.create :parser, user: user }
    let(:data_since) { 7.days.ago }
    let(:canteens) { FactoryGirl.create_list :canteen, 3 }

    let(:messages) do
      [
        FactoryGirl.create(:feedInvalidUrlError, canteen: canteens[0]),
        FactoryGirl.create(:feedFetchError, canteen: canteens[0]),
        FactoryGirl.create(:feedValidationError, canteen: canteens[0], kind: :invalid_xml),
        FactoryGirl.create(:feedUrlUpdatedInfo, canteen: canteens[1])
      ]
    end
    let(:mail) { described_class.daily_report(parser, data_since) }

    let(:parser_message) { FactoryGirl.create :feedUrlUpdatedInfo, messageable: parser }


    context 'without any source' do
      it 'should not send a mail' do
        expect(mail).to be_null_mail
      end
    end

    context 'with parser messages' do
      before { parser_message }

      it 'should sent a mail' do
        expect(mail).to_not be_null_mail

        expect(mail.to).to eq [user.notify_email]
        expect(mail.subject).to eq "OpenMensa - #{parser.name}: Unregelmäßigkeiten mit dem Parser selbst"
        expect(mail.body).to include parser_message.to_text_mail
      end

      context 'with old messages' do
        let(:parser_message) { FactoryGirl.create :feedUrlUpdatedInfo, messageable: parser, created_at: data_since - 1.day }

        it 'should not sent a mail for old messages' do
          expect(mail).to be_null_mail
        end
      end
    end

    context 'with source' do
      let!(:source) { FactoryGirl.create :source, parser: parser }
      let(:source_message) { FactoryGirl.create :feedUrlUpdatedInfo, messageable: source }

      context 'but no feeds' do
        it 'should not send a mail' do
          expect(mail).to be_null_mail
        end
      end

      context 'with source message' do
        before { source_message }

        it 'should send a mail' do
          expect(mail).to_not be_null_mail

          expect(mail.to).to eq [user.notify_email]
          expect(mail.subject).to eq "OpenMensa - #{parser.name}: Unregelmäßigkeiten mit #{source.name}"
          expect(mail.body).to include source_message.to_text_mail
        end

        it 'should have a combined subject with parser messages' do
          parser_message
          expect(mail).to_not be_null_mail

          expect(mail.to).to eq [user.notify_email]
          expect(mail.subject).to eq "OpenMensa - #{parser.name}: Unregelmäßigkeiten mit dem Parser selbst, #{source.name}"
          expect(mail.body).to include parser_message.to_text_mail
          expect(mail.body).to include source_message.to_text_mail
        end
      end

      context 'with one feed' do
        let!(:feed) { FactoryGirl.create :feed, source: source }

        context 'with new feedbacks' do
          let!(:feedback) { FactoryGirl.create :feedback, canteen: feed.canteen }
          it 'should inform about the new feedback' do
            expect(mail).to_not be_null_mail

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Neue Rückmeldung für #{feed.source.name}"
            expect(mail.body).to include feedback.message
          end

          context 'with feedback before data since' do
            let(:feedback) { FactoryGirl.create :feedback, canteen: feed.canteen, created_at: data_since - 1.day }

            it 'should not send a mail' do
              expect(mail).to be_null_mail
            end
          end

          context 'with multiple feedbacks' do
            let!(:feedback2) { FactoryGirl.create :feedback, canteen: feed.canteen }

            it 'should inform about the new feedback' do
              expect(mail).to_not be_null_mail

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Neue Rückmeldungen für #{feed.source.name}"
              expect(mail.body).to include feedback.message
              expect(mail.body).to include feedback2.message
            end
          end
        end

        context 'with new data proposals' do
          let!(:data_proposal) { FactoryGirl.create :data_proposal, canteen: feed.canteen }
          it 'should inform about the new propsoal' do
            expect(mail).to_not be_null_mail

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Neuer Änderungsvorschlag für #{feed.source.name}"
            expect(mail.body).to include canteen_data_proposals_path(data_proposal.canteen)
            expect(mail.body).to include "#{feed.canteen.city} -> #{data_proposal.city}"
          end

          context 'with feedback before data since' do
            let(:data_proposal) { FactoryGirl.create :data_proposal, canteen: feed.canteen, created_at: data_since - 1.day }

            it 'should not send a mail' do
              expect(mail).to be_null_mail
            end
          end

          context 'with multiple feedbacks' do
            let!(:data_proposal2) { FactoryGirl.create :data_proposal, canteen: feed.canteen }

            it 'should inform about the new feedback' do
              expect(mail).to_not be_null_mail

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Neue Änderungsvorschläge für #{feed.source.name}"
              expect(mail.body).to include canteen_data_proposals_path(data_proposal.canteen)
              expect(mail.body).to include canteen_data_proposals_path(data_proposal2.canteen)
              expect(mail.body).to include "#{feed.canteen.city} -> #{data_proposal.city}"
              expect(mail.body).to include "#{feed.canteen.city} -> #{data_proposal2.city}"
            end
          end
        end

        context 'with no fetches' do
          it 'should not send a mail' do
            expect(mail).to be_null_mail
          end

          context 'with feed message' do
            let!(:feed_message) { FactoryGirl.create :feedUrlUpdatedInfo, messageable: feed }

            it 'should send a mail' do
              expect(mail).to_not be_null_mail

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Unregelmäßigkeiten mit #{feed.source.name}:#{feed.name}"
              expect(mail.body).to include feed_message.to_text_mail
            end

            it 'should have a combined subject with parser messages' do
              parser_message
              source_message
              expect(mail).to_not be_null_mail

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Unregelmäßigkeiten mit dem Parser selbst, #{source.name}, #{feed.source.name}:#{feed.name}"
              expect(mail.body).to include parser_message.to_text_mail
              expect(mail.body).to include source_message.to_text_mail
              expect(mail.body).to include feed_message.to_text_mail
            end
          end

          it 'with fetches before data_since should not send a mail' do
            fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed, executed_at: data_since - 1.day
            message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch
            expect(mail).to be_null_mail
          end

          context 'with data_since be nil' do
            let(:data_since) { nil }
            it 'should send a mail' do
              fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed, executed_at: 9.days.ago
              message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch
              expect(mail).to_not be_null_mail
            end
          end
        end

        context 'with working fetches' do
          %w(changed unchanged empty).each do |state|
            it "should not send a mail on #{state} fetches" do
              FactoryGirl.create :feed_fetch, state: state, feed: feed
              expect(mail).to be_null_mail
            end
          end
        end

        context 'with one feed error' do
          it "should send a mail on failed fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed
            message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle Feeds schlagen fehl"
            expect(mail.body).to include feed.url
            expect(mail.body).to include message.to_text_mail
          end

          it "should send a mail on broken fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed
            message = FactoryGirl.create :feedFetchError, messageable: fetch

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle Feeds schlagen fehl"
            expect(mail.body).to include feed.url
            expect(mail.body).to include message.code.to_s
            expect(mail.body).to include message.message
          end

          it "should send a mail on invalid fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed
            message = FactoryGirl.create :feedValidationError, messageable: fetch, kind: :invalid_xml

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle Feeds sind invalid"
            expect(mail.body).to include feed.url
            expect(mail.body).to include message.version.to_s
            expect(mail.body).to include message.message
          end
        end

        context 'with multiple but same feed errors' do
          it "should send a mail on failed fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed
            message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch, created_at: 2.days.ago
            message2 = FactoryGirl.create :feedInvalidUrlError, messageable: fetch, created_at: 1.days.ago

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle Feeds schlagen fehl"
            expect(mail.body).to include feed.url
            expect(mail.body).to include message.to_text_mail
            expect(mail.body).to include 'Anzahl: 2'
            expect(mail.body).to include "Erstmals: #{I18n.l message.created_at}"
            expect(mail.body).to include "Zuletzt: #{I18n.l message2.created_at}"
          end

          it "should send a mail on broken fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed
            message = FactoryGirl.create :feedFetchError, messageable: fetch, created_at: 2.days.ago
            message2 = FactoryGirl.create :feedFetchError, messageable: fetch, code: message.code

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle Feeds schlagen fehl"
            expect(mail.body).to include feed.url
            expect(mail.body).to include message.code.to_s
            expect(mail.body).to include message.message
            expect(mail.body).to include 'Anzahl: 2'
            expect(mail.body).to include "Erstmals: #{I18n.l message.created_at}"
            expect(mail.body).to include "Zuletzt: #{I18n.l message2.created_at}"
          end

          it "should send a mail on invalid fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed
            message = FactoryGirl.create :feedValidationError, messageable: fetch, kind: :invalid_xml, created_at: 2.days.ago
            message2 = FactoryGirl.create :feedValidationError, messageable: fetch, kind: :invalid_xml, version: message.version

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle Feeds sind invalid"
            expect(mail.body).to include feed.url
            expect(mail.body).to include message.version.to_s
            expect(mail.body).to include message.message
            expect(mail.body).to include 'Anzahl: 2'
            expect(mail.body).to include "Erstmals: #{I18n.l message.created_at }"
            expect(mail.body).to include "Zuletzt: #{I18n.l message2.created_at }"
          end
        end

        context 'with multiple and different feed errors' do
          it "should send a mail on failed fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed
            message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch, created_at: 2.days.ago
            fetch2 = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed
            message2 = FactoryGirl.create :feedValidationError, messageable: fetch, kind: :invalid_xml, created_at: 1.days.ago

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle Feeds schlagen fehl oder sind invalid"
            expect(mail.body).to include feed.url
            expect(mail.body).to include message.to_text_mail
            expect(mail.body).to include "Zeitpunkt: #{I18n.l message.created_at}"
            expect(mail.body).to include message2.version.to_s
            expect(mail.body).to include message2.message
            expect(mail.body).to include "Zeitpunkt: #{I18n.l message2.created_at}"
          end
        end
      end

      context 'with multiple feeds' do
        let!(:feed) { FactoryGirl.create :feed, source: source }
        let!(:feed2) { FactoryGirl.create :feed, source: source }

        context 'with failed and one working feed' do
          before do
            FactoryGirl.create :feed_fetch, state: 'changed', feed: feed2
          end
          it "should send a mail on failed fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed
            message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: #{feed.name}-Feed von #{source.name} schlägt fehl"
            expect(mail.body).to include feed.url
            expect(mail.body).to include message.to_text_mail
            expect(mail.body).to_not include feed2.url
            expect(mail.body).to include "Feed #{feed2.name} ist fehlerfrei."
          end

          it "should send a mail on broken fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed
            message = FactoryGirl.create :feedFetchError, messageable: fetch

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: #{feed.name}-Feed von #{source.name} schlägt fehl"
            expect(mail.body).to include feed.url
            expect(mail.body).to include message.code.to_s
            expect(mail.body).to include message.message
            expect(mail.body).to_not include feed2.url
            expect(mail.body).to include "Feed #{feed2.name} ist fehlerfrei."
          end

          it "should send a mail on invalid fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed
            message = FactoryGirl.create :feedValidationError, messageable: fetch, kind: :invalid_xml

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: #{feed.name}-Feed von #{source.name} ist invalid"
            expect(mail.body).to include feed.url
            expect(mail.body).to include message.version.to_s
            expect(mail.body).to include message.message
            expect(mail.body).to_not include feed2.url
            expect(mail.body).to include "Feed #{feed2.name} ist fehlerfrei."
          end
        end
      end

      context 'with multiple feeds over different sources' do
        let!(:source2) { FactoryGirl.create :source, parser: parser }
        let!(:feed1_1) { FactoryGirl.create :feed, source: source }
        let!(:feed1_2) { FactoryGirl.create :feed, source: source }
        let!(:feed2_1) { FactoryGirl.create :feed, source: source2 }
        let!(:feed2_2) { FactoryGirl.create :feed, source: source2 }

        context 'with new feedbacks' do
          let!(:feedback) { FactoryGirl.create :feedback, canteen: source.canteen }
          let!(:feedback2) { FactoryGirl.create :feedback, canteen: source2.canteen }

          it 'should inform about the new feedback' do
            expect(mail).to_not be_null_mail

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Neue Rückmeldungen für #{source.name}, #{source2.name}"
            expect(mail.body).to include feedback.message
            expect(mail.body).to include feedback2.message
          end

          context 'with feedback before data since' do
            let(:feedback) { FactoryGirl.create :feedback, canteen: source.canteen, created_at: data_since - 1.day }

            it 'should not include this feedback' do
              expect(mail).to_not be_null_mail

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Neue Rückmeldung für #{source2.name}"
              expect(mail.body).to include feedback2.message
            end
          end
        end

        context 'with new data propsoals' do
          let!(:data_proposal) { FactoryGirl.create :data_proposal, canteen: source.canteen }
          let!(:data_proposal2) { FactoryGirl.create :data_proposal, canteen: source2.canteen }

          it 'should inform about the new data proposals' do
            expect(mail).to_not be_null_mail

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Neue Änderungsvorschläge für #{source.name}, #{source2.name}"
            expect(mail.body).to include "#{source.canteen.city} -> #{data_proposal.city}"
            expect(mail.body).to include "#{source.canteen.city} -> #{data_proposal2.city}"
          end

          context 'with data proposal before data since' do
            let(:data_proposal) { FactoryGirl.create :data_proposal, canteen: source.canteen, created_at: data_since - 1.day }

            it 'should not include this data proposal' do
              expect(mail).to_not be_null_mail

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Neuer Änderungsvorschlag für #{source2.name}"
              expect(mail.body).to include "#{source.canteen.city} -> #{data_proposal2.city}"
            end
          end
        end

        context 'with failed and one working feed per source' do
          before do
            FactoryGirl.create :feed_fetch, state: 'changed', feed: feed1_2
            FactoryGirl.create :feed_fetch, state: 'changed', feed: feed2_2
          end

          context 'with different names' do
            let(:feed2_1) { FactoryGirl.create :feed, source: source2, name: feed1_1.name }
            let(:feed2_2) { FactoryGirl.create :feed, source: source2, name: feed1_2.name }

            it "should send a mail on failed fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed1_1
              message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch
              fetch2 = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed2_1
              message2 = FactoryGirl.create :feedInvalidUrlError, messageable: fetch2

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle #{feed1_1.name}-Feeds schlagen fehl"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.to_text_mail
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.to_text_mail
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end

            it "should send a mail on broken fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed1_1
              message = FactoryGirl.create :feedFetchError, messageable: fetch
              fetch2 = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed2_1
              message2 = FactoryGirl.create :feedFetchError, messageable: fetch2

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle #{feed1_1.name}-Feeds schlagen fehl"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.code.to_s
              expect(mail.body).to include message.message
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.code.to_s
              expect(mail.body).to include message2.message
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end

            it "should send a mail on invalid fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed1_1
              message = FactoryGirl.create :feedValidationError, messageable: fetch, kind: :invalid_xml
              fetch2 = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed2_1
              message2 = FactoryGirl.create :feedValidationError, messageable: fetch2, kind: :invalid_xml

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle #{feed1_1.name}-Feeds sind invalid"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.version.to_s
              expect(mail.body).to include message.message
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.version.to_s
              expect(mail.body).to include message2.message
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end
          end

          context 'with same names' do
            it "should send a mail on failed fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed1_1
              message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch
              fetch2 = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed2_1
              message2 = FactoryGirl.create :feedInvalidUrlError, messageable: fetch2

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Feeds schlagen fehl"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.to_text_mail
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.to_text_mail
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end

            it "should send a mail on broken fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed1_1
              message = FactoryGirl.create :feedFetchError, messageable: fetch
              fetch2 = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed2_1
              message2 = FactoryGirl.create :feedFetchError, messageable: fetch2

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Feeds schlagen fehl"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.code.to_s
              expect(mail.body).to include message.message
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.code.to_s
              expect(mail.body).to include message2.message
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end

            it "should send a mail on invalid fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed1_1
              message = FactoryGirl.create :feedValidationError, messageable: fetch, kind: :invalid_xml
              fetch2 = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed2_1
              message2 = FactoryGirl.create :feedValidationError, messageable: fetch2, kind: :invalid_xml

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Feeds sind invalid"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.version.to_s
              expect(mail.body).to include message.message
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.version.to_s
              expect(mail.body).to include message2.message
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end
          end
        end

        context 'with failing source and one working source' do
          before do
            FactoryGirl.create :feed_fetch, state: 'changed', feed: feed1_1
            FactoryGirl.create :feed_fetch, state: 'changed', feed: feed1_2
          end
          it "should send a mail on failed fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed2_1
            message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch
            fetch2 = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed2_2
            message2 = FactoryGirl.create :feedInvalidUrlError, messageable: fetch2

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle Feeds von #{source2.name} schlagen fehl"
            expect(mail.body).to include feed2_1.url
            expect(mail.body).to include message.to_text_mail
            expect(mail.body).to include feed2_2.url
            expect(mail.body).to include message2.to_text_mail
            expect(mail.body).to_not include source.canteen.name
            expect(mail.body).to_not include source.name
            expect(mail.body).to_not include feed1_1.url
            expect(mail.body).to_not include feed1_2.url
          end

          it "should send a mail on broken fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed2_1
            message = FactoryGirl.create :feedFetchError, messageable: fetch
            fetch2 = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed2_2
            message2 = FactoryGirl.create :feedFetchError, messageable: fetch2

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle Feeds von #{source2.name} schlagen fehl"
            expect(mail.body).to include feed2_1.url
            expect(mail.body).to include message.code.to_s
            expect(mail.body).to include message.message
            expect(mail.body).to include feed2_2.url
            expect(mail.body).to include message2.code.to_s
            expect(mail.body).to include message2.message
            expect(mail.body).to_not include source.canteen.name
            expect(mail.body).to_not include source.name
            expect(mail.body).to_not include feed1_1.url
            expect(mail.body).to_not include feed1_2.url
          end

          it "should send a mail on invalid fetches" do
            fetch = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed2_1
            message = FactoryGirl.create :feedValidationError, messageable: fetch, kind: :invalid_xml
            fetch2 = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed2_2
            message2 = FactoryGirl.create :feedValidationError, messageable: fetch2, kind: :invalid_xml

            expect(mail.to).to eq [user.notify_email]
            expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle Feeds von #{source2.name} sind invalid"
            expect(mail.body).to include feed2_1.url
            expect(mail.body).to include message.version.to_s
            expect(mail.body).to include message.message
            expect(mail.body).to include feed2_2.url
            expect(mail.body).to include message2.version.to_s
            expect(mail.body).to include message2.message
            expect(mail.body).to_not include source.canteen.name
            expect(mail.body).to_not include source.name
            expect(mail.body).to_not include feed1_1.url
            expect(mail.body).to_not include feed1_2.url
          end
        end

        context 'with working source and one failing and one working feed per other source' do
          let!(:source3) { FactoryGirl.create :source, parser: parser }
          let!(:feed3_1) { FactoryGirl.create :feed, source: source3 }
          let!(:feed3_2) { FactoryGirl.create :feed, source: source3 }
          before do
            FactoryGirl.create :feed_fetch, state: 'changed', feed: feed1_2
            FactoryGirl.create :feed_fetch, state: 'changed', feed: feed2_2
            FactoryGirl.create :feed_fetch, state: 'changed', feed: feed3_1
            FactoryGirl.create :feed_fetch, state: 'changed', feed: feed3_2
          end

          context 'with same names' do
            let(:feed2_1) { FactoryGirl.create :feed, source: source2, name: feed1_1.name }
            let(:feed2_2) { FactoryGirl.create :feed, source: source2, name: feed1_2.name }

            it "should send a mail on failed fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed1_1
              message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch
              fetch2 = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed2_1
              message2 = FactoryGirl.create :feedInvalidUrlError, messageable: fetch2

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle #{feed1_1.name}-Feeds von #{source.name}, #{source2.name} schlagen fehl"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.to_text_mail
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.to_text_mail
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end

            it "should send a mail on broken fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed1_1
              message = FactoryGirl.create :feedFetchError, messageable: fetch
              fetch2 = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed2_1
              message2 = FactoryGirl.create :feedFetchError, messageable: fetch2

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle #{feed1_1.name}-Feeds von #{source.name}, #{source2.name} schlagen fehl"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.code.to_s
              expect(mail.body).to include message.message
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.code.to_s
              expect(mail.body).to include message2.message
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end

            it "should send a mail on invalid fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed1_1
              message = FactoryGirl.create :feedValidationError, messageable: fetch, kind: :invalid_xml
              fetch2 = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed2_1
              message2 = FactoryGirl.create :feedValidationError, messageable: fetch2, kind: :invalid_xml

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Alle #{feed1_1.name}-Feeds von #{source.name}, #{source2.name} sind invalid"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.version.to_s
              expect(mail.body).to include message.message
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.version.to_s
              expect(mail.body).to include message2.message
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end
          end

          context 'with different names' do
            it "should send a mail on failed fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed1_1
              message = FactoryGirl.create :feedInvalidUrlError, messageable: fetch
              fetch2 = FactoryGirl.create :feed_fetch, state: 'failed', feed: feed2_1
              message2 = FactoryGirl.create :feedInvalidUrlError, messageable: fetch2

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Feeds von #{source.name}, #{source2.name} schlagen fehl"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.to_text_mail
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.to_text_mail
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end

            it "should send a mail on broken fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed1_1
              message = FactoryGirl.create :feedFetchError, messageable: fetch
              fetch2 = FactoryGirl.create :feed_fetch, state: 'broken', feed: feed2_1
              message2 = FactoryGirl.create :feedFetchError, messageable: fetch2

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Feeds von #{source.name}, #{source2.name} schlagen fehl"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.code.to_s
              expect(mail.body).to include message.message
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.code.to_s
              expect(mail.body).to include message2.message
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end

            it "should send a mail on invalid fetches" do
              fetch = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed1_1
              message = FactoryGirl.create :feedValidationError, messageable: fetch, kind: :invalid_xml
              fetch2 = FactoryGirl.create :feed_fetch, state: 'invalid', feed: feed2_1
              message2 = FactoryGirl.create :feedValidationError, messageable: fetch2, kind: :invalid_xml

              expect(mail.to).to eq [user.notify_email]
              expect(mail.subject).to eq "OpenMensa - #{parser.name}: Feeds von #{source.name}, #{source2.name} sind invalid"
              expect(mail.body).to include feed1_1.url
              expect(mail.body).to include message.version.to_s
              expect(mail.body).to include message.message
              expect(mail.body).to include feed2_1.url
              expect(mail.body).to include message2.version.to_s
              expect(mail.body).to include message2.message
              expect(mail.body).to_not include feed1_2.url
              expect(mail.body).to include "Feed #{feed1_2.name} ist fehlerfrei."
              expect(mail.body).to_not include feed2_2.url
              expect(mail.body).to include "Feed #{feed2_2.name} ist fehlerfrei."
            end
          end
        end
      end
    end
  end
end
