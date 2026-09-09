<?php
require dirname(__DIR__) . '/php-demo/PGYERAppUploader.php';
class FixtureUploader extends PGYERAppUploader {
    public $base;
    public function __construct($base) { $this->base=$base; }
    public function sendRequest($url,$params=[],&$httpcode=0,$timeout=null) {
        if (strpos($url,'/')===0) {$url=$this->base.$url;}
        return parent::sendRequest($url,$params,$httpcode,$timeout);
    }
}
$result=(new FixtureUploader($argv[1]))->upload(['filePath'=>$argv[2]]);
exit($result ? 0 : 1);
