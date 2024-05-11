use strict;
use warnings;
use HTTP::Tiny;
use HTML::TreeBuilder;
use DBI;

package Hoodie {
    use Moo;
    has 'name' => (is => 'ro');
    has 'price' => (is => 'ro');
    has 'availability' => (is => 'ro');
    has 'link' => (is => 'ro');
}

my $dbh = DBI->connect("dbi:SQLite:dbname=hoodies.db","","");

$dbh->do("CREATE TABLE IF NOT EXISTS hoodies (
    id INTEGER PRIMARY KEY,
    name TEXT,
    price TEXT,
    availability TEXT,
    link TEXT
)");

my $http = HTTP::Tiny->new();
my $response = $http->get('https://juvenileeg.com/collections/hoodies');
my $html_content = $response->{content};
my $tree = HTML::TreeBuilder->new();
$tree->parse($response->{content});

my @hoodie_products;

my @htmlcontent = $tree->look_down('_tag', 'div', class => qr/\binnerer\b/);
foreach my $htmlcont (@htmlcontent) {
    my $product_name = $htmlcont->look_down('_tag', 'div', class => qr/\bproduct-block__title\b/);
    my $name_text = $product_name ? $product_name->as_trimmed_text : '';

    my $product_price = $htmlcont->look_down('_tag', 'span', class => qr/\bproduct-price__item product-price__amount  theme-money\b/);
    my $price_text = $product_price ? $product_price->as_trimmed_text : '';

    my $availability = $htmlcont->look_down('_tag', 'span', class => qr/\bproduct-price__item price-label price-label--sold-out\b/);
    my $availability_text = $availability ? 'Sold Out' : 'Available';

    my $product_link = $htmlcont->look_down('_tag', 'a', class => qr/\bproduct-link\b/);
    my $link_text = $product_link ? $product_link->attr('href') : '';

    $link_text = "https://juvenileeg.com$link_text" if $link_text;

    my $hoodie_product = Hoodie->new(
        name => $name_text,
        price => $price_text,
        availability => $availability_text,
        link => $link_text,
    );

    push @hoodie_products, $hoodie_product;
}

@hoodie_products = sort {$a->availability cmp $b->availability} @hoodie_products;
my $insert_hoodie = $dbh->prepare("INSERT INTO hoodies (name, price, availability, link) VALUES (?, ?, ?, ?)");
foreach my $hoodie_product (@hoodie_products) {
    $insert_hoodie->execute($hoodie_product->name, $hoodie_product->price, $hoodie_product->availability, $hoodie_product->link);
}
print "Completed, check the database file in your folder";
$dbh->disconnect;

$tree->delete;
