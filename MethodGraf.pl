#!/usr/bin/perl
use strict;
use Encode;
use File::Find;
use Cwd;
use Data::Dumper;   
use utf8;
use List::MoreUtils qw(uniq);
use 5.016;
use Benchmark; # Для замера выполнения кода

my $start_time = Benchmark->new;

my $file_name; 
my @directories_to_search = (getcwd); # Текущая директория.  
my %InfoMethods;


binmode(STDOUT,':utf8');


find(\&wanted, @directories_to_search);
sub wanted {
    #BuildMethodList($_) if /^(.*).bsl$/;
    ParsFile($_) if /^(.*).bsl$/;
}

my $end_time = Benchmark->new;
my $delta = timediff($end_time, $start_time);
say "\n\nВремя выполнение скрипта:\n" . timestr($delta);

=foreach(keys %InfoMethods) {
    print decode('Windows-1251', $_) . "\r\n================\r\n\r\n" . 
    decode('Windows-1251', $InfoMethods{$_}{ModulePath}) ."\r\n";

    foreach(@{$InfoMethods{$_}{Method}} ) { 
         print "$_\r\n";
    }
}   
=cut

foreach(values %InfoMethods) {
    @directories_to_search = $$_{ModulePath};
    find(\&callback, @directories_to_search);
}

sub callback {
    return unless(/^(.*).bsl$/);

    my $txt = OpenAndReadFile($_);

    my $MetaDataName = getMetaDataName($File::Find::dir);

    #print "$MetaDataName\r\n";
   # print $#{$InfoMethods{$MetaDataName}{MethodName}};

    #map {print "$_\r\n"} @{$InfoMethods{$MetaDataName}{Method}};

    map {$_ = decode('Windows-1251', $MetaDataName) . ".$_"} @{$InfoMethods{$MetaDataName}{Method}};
    #map {print "$_\r\n"} @{$InfoMethods{$MetaDataName}{Method}};
    #map {print "$_\r\n"} @methods;

   # 
  # my @m = (1,1,1,7,45);

    # Удаляем дубли в массиве
   # foreach(@methods) {
     #   print "$_\r\n";
  #  }
   BuildCoupling($InfoMethods{$MetaDataName}{Method}, $txt);
}


sub ParsFile() {
    my $fileName = shift;
    my $txt = OpenAndReadFile($fileName);


    my $ConditionF = "Функция[\\s]+(?:.+?)[(][^)]+[)][\\s]+(?:Экспорт)?(?<body>.+?)конецфункции";
    my $ConditionP = "Процедура[\\s]+(?:.+?)[(][^)]+[)][\\s]+(?:Экспорт)?(?<body>.+?)конецпроцедуры";

    #say "==========\n" . decode('Windows-1251', $File::Find::dir) . "\n";
    my $MethodBody = $+{body} if $txt =~ /$ConditionF/msiu or $txt =~ /$ConditionP/msiu;
    ParsCalls($MethodBody);
}
   
sub ParsCalls() {
    my $MethodBody = shift;
    my @Buffer;

   # Мне кажется, что костыльно, но как получилось
    foreach(split("\n", $MethodBody)) { 
      my @calls = $_ =~ /([\w]+[\.][\w]+)[(]/mgiu; # через точку, т.е. не будут учитываться локальные методы. Правда с глобальными методами засада получается.
      
      # Если выше есть не "закрытые" Если значит вызов из блока условия.
      if(@calls) {
        my $JBuffer = join("\n", @Buffer);
        my @St = $JBuffer =~ /[\s]+\KЕсли(?:.+?)Тогда|^Если(?:.+?)Тогда/mgsiu;
        my @En = $JBuffer =~ /[\s]+КонецЕсли|^КонецЕсли/mgiu;
        my $Count += $#St;
        $Count -= $#En;  

        if($Count != 0) {
            local $" = ",";
            #say "Вызовы @calls в условии - вероятность вызова ". (100/2**$Count) . "%";
        } else {
           # say "Вызовы @calls вне условия, вероятность 100%";
        }
        
      }

      push(@Buffer, $_);
    }


    #my $PartBody = $2 if $MethodBody =~ /[\s]Если(.+?)Тогда(.*)КонецЕсли/sgiu;
   # my $PartBody = GetPart("Если", "КонецЕсли", $MethodBody);

    #print $PartBody;

#exit;
   # print "--------------\r\n";

   # ParsCalls($PartBody) if $PartBody;
}

sub GetPart() { 
    my ($Start, $End, $MethodBody) = @_;
    my $result = $MethodBody;

    my $Flag = undef;
    foreach(split("\n", $MethodBody)) {
        my @S = $_ =~ /([\s]+$Start|^$Start)/giu;
        my @E = $_ =~ /([\s]+$End|^$End)/giu;

        $Flag += $#S;
        $Flag -= $#E;
        
        last if $Flag == 0;
    }


print "-----------$_\n" if $Flag == 0;
    return $result;
}

sub BuildMethodList() {
    my ($fileName) = @_;
    my $txt = OpenAndReadFile($fileName);

    my @func = $txt =~ /^[\s]?функция[\s]+([\w]+)[(]/mgiu;
    my @proc = $txt =~ /^[\s]?процедура[\s]+([\w]+)[(]/mgiu;
    my @methods = ();
    push(@methods, @func);
    push(@methods, @proc); 

    my $MetaDataName = getMetaDataName($File::Find::dir);
    $InfoMethods{$MetaDataName} = {Method => [], ModulePath => $File::Find::dir} unless defined($InfoMethods{$MetaDataName});
    map {push(@{$InfoMethods{$MetaDataName}{Method}}, {Name => $_, probability => 1})}  uniq(@methods);
    #map {push(@{$InfoMethods{$MetaDataName}{Method}}, $_)}  uniq(@methods);
}

sub BuildCoupling() {
    my ($methods, $txt) = @_;

    my %Coupling;
    #PossibilityCall => 0

    foreach(@$methods) {
        my @breakPath = split("[\.]", $_);
        my $methodName = pop(@breakPath);
        my $moduleName = pop(@breakPath);

        #

        my $ConditionF = "функция[\\s]+".$methodName."[(][^)]+[)][\\s]+(Экспорт)?(.+?)конецфункции";
        my $ConditionP = "процедура[\\s]+".$methodName."[(][^)]+[)][\\s]+(Экспорт)?(.+?)конецпроцедуры";

        my $MethodBody = $2 if $txt =~ /$ConditionF/msiu or $txt =~ /$ConditionP/msiu;
       # my @calls = $MethodBody =~ /([\w]+[\.][\w]+)[(]|([\w]+)[(]/mgiu;
        my @calls = $MethodBody =~ /([\w]+[\.][\w]+)[(]/mgiu;
       
        #my @callsSelf = $MethodBody =~ /([\w]+)[(]/mgiu;
        #push(@calls, @callsSelf);

       print  "=== CALLS $_ === \r\n";
        
        foreach(uniq(@calls)) {
            #print "$_\r\n";
            #my $AbsolutePath = "$moduleName.$_" unless /[\.]/;
        
            my $call = $_;
           # print "$call\r\n";
            #print "$AbsolutePath\r\n";
            foreach(keys %InfoMethods) {
                #print decode('Windows-1251', $_) . "\r\n";
                #map {print "$call = $_\r\n"} @{$InfoMethods{$_}{Method}};
               # print decode('Windows-1251', $_) . " = " . "$moduleName\r\n";
                #print "$AbsolutePath\r\n"  if grep { $AbsolutePath eq $_ }  @{$InfoMethods{$_}{Method}};# and decode('Windows-1251', $_) ne $moduleName;
              print "$call\r\n" if grep { $call eq $_ } @{$InfoMethods{$_}{Method}} and decode('Windows-1251', $_) ne $moduleName;
            }
            
        }
     #   print  "=== END CALLS === \r\n";
    }

    

}

sub OpenAndReadFile() {
    my ($fileName) = @_;
    open(my $FH, "<:encoding(utf8)", $fileName) or die "Ошибка открытия файла $fileName";

    my $txt;
    {
        local $/ = "\r";
        $txt = <$FH>;
    }

    close $FH;
    return $txt;
    
}

sub getMetaDataName() {
    my ($Path) = @_;
    my @breakPath = split("/", $Path);

    # Имя модуля второе с низу. 
    pop(@breakPath);
    my $MetaDataName = pop(@breakPath);
}