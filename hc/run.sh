dart compile exe src/hc_2021_cli.dart -o bin/hc_2021_cli

echo "\n🏃‍ Running dataset A..."
bin/hc_2021_cli inputs/a.txt outputs/a.txt > logs/a.txt

echo "\n🏃‍ Running dataset B..."
bin/hc_2021_cli inputs/b.txt outputs/b.txt > logs/b.txt

# echo "\n🏃‍ Running dataset C..."
# bin/hc_2021_cli inputs/c.txt outputs/c.txt > logs/c.txt

# echo "\n🏃‍ Running dataset D..."
# bin/hc_2021_cli inputs/d.txt outputs/d.txt > logs/d.txt

echo "\n🏃‍ Running dataset E..."
bin/hc_2021_cli inputs/e.txt outputs/e.txt > logs/e.txt

echo "\n🏃‍ Running dataset F..."
bin/hc_2021_cli inputs/f.txt outputs/f.txt > logs/f.txt