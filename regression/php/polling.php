<?php
require __DIR__ . '/../../php-demo/PGYERAppUploader.php';

class MockUploader extends PGYERAppUploader
{
    public $calls = 0;
    private $test;
    public function __construct($test) { $this->test = $test; }
    public function sendRequest($url, $params = [], &$httpcode = 0, $timeout = null)
    {
        if ($url === '/apiv2/app/getCOSToken') {
            return json_encode(['code' => 0, 'data' => [
                'key' => 'fixture.apk', 'endpoint' => 'https://storage.invalid/',
                'params' => ['key' => 'fixture.apk', 'signature' => 'fixture', 'x-cos-security-token' => 'fixture']
            ]]);
        }
        if ($url === 'https://storage.invalid/') {
            if (array_key_last($params) !== 'file') throw new Exception('file must remain last');
            $httpcode = 204;
            return '';
        }
        if (strpos($url, '/apiv2/app/buildInfo?') !== 0) throw new Exception('Unexpected request');
        $index = $this->calls++;
        if (!empty($this->test['transportError'])) throw new Exception('mock transport failure');
        if ($index >= count($this->test['responses'])) throw new Exception('Unexpected extra poll');
        $response = $this->test['responses'][$index];
        return is_string($response) ? $response : json_encode($response);
    }
}

$cases = json_decode(file_get_contents($argv[1]), true);
$file = tempnam(sys_get_temp_dir(), 'pgyer-poll-');
$apk = $file . '.apk';
rename($file, $apk);
try {
    foreach ($cases as $test) {
        $uploader = new MockUploader($test);
        $error = null;
        $result = null;
        try { $result = $uploader->upload(['filePath' => $apk]); }
        catch (Exception $ex) { $error = $ex; }
        $name = $test['name'];
        if ($uploader->calls !== $test['requests']) throw new Exception("$name: request count " . $uploader->calls);
        if (array_key_exists('errorContains', $test)) {
            if (!$error) throw new Exception("$name: expected failure");
            foreach ($test['errorContains'] as $part)
                if (strpos($error->getMessage(), $part) === false) throw new Exception("$name: lost original error: " . $error->getMessage());
        } elseif ($error || ($result['buildKey'] ?? '') !== 'fixture') {
            throw new Exception("$name: expected build info", 0, $error);
        }
        echo "PASS PHP $name\n";
    }
} finally { unlink($apk); }
