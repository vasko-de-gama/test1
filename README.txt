Запустите
./parse ./log/out.log (ВНИМАНИЕ скрипт очищает рабочие таблицы)

Создайте базу
Создайте таблицы message и log
Настройте подключение в MySettings.pm
запустите ./server.pl 
зайдите на страницу http://%YOUR_HOST%:%PORT%/

Введите в строку поиска e-mail
например ksppvvxxdo@yahoo.com

Необходимые модули 

HTTP::Server::Simple
Data::Dumper
XML::LibXSLT
XML::LibXML
Time::HiRes


