package Everything::Page::faq_editor;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::faq_editor - FAQ Editor for creating/editing FAQ entries

=head1 DESCRIPTION

Admin tool for creating new FAQ entries or editing existing ones.
Handles question, answer, and keywords for FAQ entries.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns FAQ data for editing, or handles create/update operations.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $CGI = $REQUEST->cgi;
    my $USER = $REQUEST->user;
    my $APP = $self->APP;

    my $faq_id = $CGI->param('faq_id') || 0;
    my $success_message = '';

    # Handle form submission
    if ($CGI->param('sexisgood')) {
        my $question = $CGI->param('faq_question') || '';
        my $answer = $CGI->param('faq_answer') || '';
        my $keywords = $CGI->param('faq_keywords') || '';

        if ($CGI->param('edit_faq')) {
            # Update existing FAQ
            my $edit_id = $CGI->param('edit_faq');
            $DB->sqlUpdate(
                'faq',
                {
                    question => $question,
                    answer => $answer,
                    keywords => $keywords
                },
                "faq_id = $edit_id"
            );
            $faq_id = $edit_id;
            $success_message = 'FAQ entry updated successfully.';
        } else {
            # Create new FAQ
            $DB->sqlInsert(
                'faq',
                {
                    question => $question,
                    answer => $answer,
                    keywords => $keywords
                }
            );
            $success_message = 'FAQ entry created successfully.';
            # Get the new ID
            $faq_id = $DB->{dbh}->last_insert_id(undef, undef, 'faq', 'faq_id');
        }
    }

    # Load FAQ data if editing
    my $faq_data = {};
    if ($faq_id) {
        $faq_data = $DB->sqlSelectHashref('*', 'faq', "faq_id = $faq_id");
        if (!$faq_data) {
            return {
                type => 'faq_editor',
                error => "FAQ entry #$faq_id not found."
            };
        }
    }

    return {
        type => 'faq_editor',
        faq_id => int($faq_id),
        question => $faq_data->{question} || '',
        answer => $faq_data->{answer} || '',
        keywords => $faq_data->{keywords} || '',
        success_message => $success_message
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
