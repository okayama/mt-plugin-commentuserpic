package MT::Plugin::CommentUserPic;

######################### Setting etc. #########################

use strict;
use MT;
use MT::Plugin;
use MT::Template;
use MT::Template::Context;
use MT::Util qw( dirify );

use File::Spec;

our $VERSION = '0.1';

use base qw( MT::Plugin );

@MT::Plugin::CommentUserPic::ISA = qw(MT::Plugin);

my $plugin = __PACKAGE__->new({
    id => 'CommentUserPic',
    key => 'commentuserpic',
    name => 'CommentUserPic',
    author_name => 'okayama', 
    author_link => 'http://weeeblog.net/',
    description => '<MT_TRANS phrase=\'_PLUGIN_DESCRIPTION\'>',
    version => $VERSION,
    l10n_class => 'CommentUserPic::L10N',
});

MT->add_plugin($plugin);

my $DEBUG = 1;

#################################### Init Plugin ####################################

sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        callbacks => {
            'api_post_save.author'
                => \&_api_post_save_author,
            'MT::App::Comments::template_source.profile'
                => \&_cb_profile,
        },
        tags => {
            function => {
                CommenterPicURL => \&_commenter_pic_url,
            },
        },
    });
}


#################################### tag #####################################

sub _commenter_pic_url {
    my ( $ctx, $args, $cond ) = @_;
    my $author = $ctx->stash( 'author' );
    unless ( $author ) {
        my $name = $ctx->var( 'name' );
        $author = MT::Author->load({ name => $name });
    }
    if ( $author ) {
        my $asset_id = $author->userpic_asset_id;
        my $asset = MT::Asset->load({ id => $asset_id });
        return $asset ? $asset->url : '';
    }
    return '';
}


#################################### tmpl transform #####################################

sub _cb_profile {
    my ( $cb, $app, $tmpl ) = @_;
    $$tmpl =~ s/(<form\smethod="post")(.*?>)/$1 enctype="multipart\/formdata"$2/;
    my $add =<<'MTML';
    <input type="hidden" name="blog_id" value="<$mt:BlogID$>" />
    <input type="hidden" name="middle_path" value="" />
    <input type="hidden" name="entry_insert" value="" />
    <input type="hidden" name="asset_select" value="" />
    <input type="hidden" name="edit_field" value="" />
    <input type="hidden" name="require_type" value="" />
    <input type="hidden" name="overwrite_no" value="1" />
MTML
    $$tmpl =~ s/(<form\smethod="post".*?)(<input\stype="hidden)/$1$add$2/s;  
    $add =<<'MTML';
<mt:var name="userpic_asset_id">
    <mtapp:setting
        id="commenter_pic"
        label="<__plugintrans phrase="Profile Images">"
        label_class="top-label"
        hint="<__plugintrans phrase="Your Profile Images.">">
<mt:IfNonEmpty tag="CommenterPicURL">
        <p><img src="<$mt:CommenterPicURL$>" /></p>
</mt:IfNonEmpty>
        <input type="file" name="file" id="file" value="" />
    </mtapp:setting>
MTML
    $add =~ s/<__plugintrans phrase="(.*?)">/$plugin->translate($1)/eg;
    my $pointer = '<p><input type="submit" name="submit"';
    my $q_pointer = quotemeta( $pointer );
    $$tmpl =~ s/$q_pointer/$add$pointer/;
}


#################################### save userpic #####################################

sub _api_post_save_author {
    my ( $eh, $app, $cmntr ) = @_;
    my $q = $app->param;
    if ( $q->param( 'file' ) ) {
        if ( $app->user->userpic_asset_id ) {
            my $asset_id = $app->user->userpic_asset_id;
            use MT::Asset;
            my $asset = MT::Asset->load({ id => $asset_id });
            $asset->remove;
        }
        use MT::CMS::Asset;
        my ( $asset, $bytes ) = MT::CMS::Asset::_upload_file( $app );
        if ( $asset ) {
            $cmntr->userpic_asset_id( $asset->id );
            $cmntr->save;
        }
    }
1;
}
