my @arr = ( 
	"shellies/#", "testing/#", "my/good/old/topic", "/what/the/heck/#", "/what/else", "nice/topic"
);

my @arr = sort { ($b=~tr/\///) <=> ($a=~tr/\///) } @arr;

print join("\n", @arr) . "\n";

