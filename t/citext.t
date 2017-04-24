#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Mojo::File qw/path/;
use Mojo::Pg;

plan skip_all => 'set TEST_ONLINE to enable this test'
  unless $ENV{TEST_ONLINE};

my $pg = Mojo::Pg->new($ENV{TEST_ONLINE});
$pg->migrations->name(path($0)->realpath)->from_data->migrate;

sub insert {
  my $table = shift;
  $pg->db->query(<<"  SQL", @_)
    INSERT INTO $table (name, email)
      VALUES (?, ?)
  SQL
}

for my $table (qw/ciemails emails/) {
  insert $table, 'Paul',   'MY@email.com';
  insert $table, 'Steven', 'his@EMAIL.com';
}

subtest ciemails => sub {
  is $pg->db->query("SELECT name FROM ciemails WHERE email='my\@email.com'")
    ->hash->{name}, 'Paul', 'can use any case';
  is $pg->db->query("SELECT name FROM ciemails WHERE email='HIS\@EMAIL.com'")
    ->hash->{name}, 'Steven', 'can use any case';
  is $pg->db->query("SELECT email FROM ciemails WHERE email='HIS\@EMAIL.com'")
    ->hash->{email}, 'his@EMAIL.com', 'email matches inserted value';

  like $pg->db->query(
    "EXPLAIN SELECT name FROM emails WHERE email='my\@email.com'")->text,
    qr/Index Scan/, 'uses index scan';
};

subtest emails => sub {
  is $pg->db->query("SELECT name FROM emails WHERE email='my\@email.com'")
    ->hash, undef, 'cannot use any case';
  is $pg->db->query("SELECT name FROM emails WHERE email='HIS\@EMAIL.com'")
    ->hash, undef, 'cannot use any case';
  is $pg->db->query("SELECT email FROM emails WHERE email='his\@EMAIL.com'")
    ->hash->{email}, 'his@EMAIL.com', 'must match case';
};

done_testing;

END { $pg->migrations->name(path($0)->realpath)->from_data->migrate(0) }

__DATA__
@@ t/citext.t
-- 1 up

CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE ciemails (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email CITEXT NOT NULL
);
CREATE INDEX idx_ciemails_email ON ciemails USING btree (email);

CREATE TABLE emails (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL
);
CREATE INDEX idx_emails_email ON emails USING btree (email);

-- 1 down
DROP TABLE IF EXISTS ciemails;
DROP TABLE IF EXISTS emails;

DROP EXTENSION IF EXISTS citext CASCADE;
