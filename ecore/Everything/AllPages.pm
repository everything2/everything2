package Everything::AllPages;

# Preload module - loads all Page classes at server startup
# This allows:
# 1. Compile errors to be caught at startup time (fail fast)
# 2. Page classes already in memory (no runtime loading)
# 3. No need to search @INC on every request

use strict;
use warnings;

# Load all Page classes
use Everything::Page::25;
use Everything::Page::a_year_ago_today;
use Everything::Page::about_nobody;
use Everything::Page::chatterbox_help_topics;
use Everything::Page::e2_full_text_search;
use Everything::Page::e2_staff;
use Everything::Page::e2n;
use Everything::Page::ekn;
use Everything::Page::enn;
use Everything::Page::everything2_elsewhere;
use Everything::Page::everything_new_nodes;
use Everything::Page::everything_s_obscure_writeups;
use Everything::Page::fezisms_generator;
use Everything::Page::golden_trinkets;
use Everything::Page::ipfrom;
use Everything::Page::is_it_april_fools_day_yet;
use Everything::Page::is_it_christmas_yet;
use Everything::Page::is_it_halloween_yet;
use Everything::Page::is_it_new_year_s_day_yet;
use Everything::Page::is_it_new_year_s_eve_yet;
use Everything::Page::kaizen_ui_preview;
use Everything::Page::list_html_tags;
use Everything::Page::manna_from_heaven;
use Everything::Page::node_tracker2;
use Everything::Page::nodeshells;
use Everything::Page::oblique_strategies_garden;
use Everything::Page::online_only_msg;
use Everything::Page::other_users_xml_ticker;
use Everything::Page::piercisms_generator;
use Everything::Page::recent_node_notes;
use Everything::Page::sanctify;
use Everything::Page::sign_up;
use Everything::Page::silver_trinkets;
use Everything::Page::wharfinger_s_linebreaker;
use Everything::Page::what_to_do_if_e2_goes_down;
use Everything::Page::wheel_of_surprise;
use Everything::Page::your_gravatar;
use Everything::Page::your_ignore_list;
use Everything::Page::your_insured_writeups;
use Everything::Page::your_nodeshells;

1;
