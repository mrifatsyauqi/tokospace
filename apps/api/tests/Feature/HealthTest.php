<?php

test('GET /health reports ok when database and redis are reachable', function () {
    $response = $this->get('/health');

    $response->assertOk();
    $response->assertJson([
        'status' => 'ok',
        'checks' => [
            'database' => true,
        ],
    ]);
});
